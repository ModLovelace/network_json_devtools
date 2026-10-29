// Local-only HTTP traffic with a new disposable RSA key for each run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_json_devtools/network_json_devtools.dart';
import 'support/sample_exchange.dart';

Future<void> main() async {
  final keys = SampleKeys.generate();
  final temporary = await Directory.systemTemp.createTemp('network-json-demo-');
  final pemFile = await File(
    '${temporary.path}/sample.pem',
  ).writeAsString(keys.privatePem);
  final decoder = DecryptionSession(
    DecryptionSettings(privateKeyPem: keys.privatePem),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final client = HttpClient();
  final pending = <String, SampleExchange>{};
  var sequence = 0;
  var stopped = false;

  server.listen((request) async {
    final text = await utf8.decoder.bind(request).join();
    final decoded = decoder.decode(text, '').request;
    final sample = pending[request.uri.pathSegments.last];
    request.response.headers.contentType = ContentType.json;
    if (!decoded.decrypted || sample == null) {
      request.response.statusCode = 400;
      request.response.write('{"error":"Invalid sample envelope"}');
    } else {
      final response = {
        'ok': true,
        'data': {
          'sequence': sequence,
          'echo': decoded.value,
          'source': 'localhost',
        },
      };
      request.response.write(jsonEncode({'data': sample.encrypt(response)}));
    }
    await request.response.close();
  });

  Future<void> send() async {
    if (stopped) return;
    final id = '${++sequence}';
    final sample = SampleExchange(keys, sequence: sequence);
    pending[id] = sample;
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/api/demo/$id'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(sample.request));
      final response = await request.close();
      await response.drain<void>();
    } finally {
      pending.remove(id);
    }
  }

  final timer = Timer.periodic(
    const Duration(seconds: 2),
    (_) => unawaited(send()),
  );
  stdout.writeln('Sample PEM: ${pemFile.path}');
  stdout.writeln(
    'Demo local activa. Las peticiones se generan cada 2 s. Ctrl+C para cerrar.',
  );
  Future<void> stop() async {
    if (stopped) return;
    stopped = true;
    timer.cancel();
    client.close(force: true);
    await server.close(force: true);
    await temporary.delete(recursive: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(stop()));
  ProcessSignal.sigterm.watch().listen((_) => unawaited(stop()));
  await send();
}
