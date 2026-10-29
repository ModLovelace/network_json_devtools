import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final child = await Process.start(Platform.resolvedExecutable, [
    '--observe=0',
    'example/main.dart',
  ], workingDirectory: root.path);
  final uriReady = Completer<Uri>();
  final pemReady = Completer<String>();
  void inspect(String line) {
    if (line.startsWith('Sample PEM: ') && !pemReady.isCompleted) {
      pemReady.complete(line.substring('Sample PEM: '.length));
    }
    final match = RegExp(
      r'The Dart VM service is listening on (http://\S+)',
    ).firstMatch(line);
    if (match != null && !uriReady.isCompleted) {
      uriReady.complete(Uri.parse(match.group(1)!));
    }
  }

  final out = child.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(inspect);
  final err = child.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(inspect);
  VmService? vm;
  try {
    final uri = await uriReady.future.timeout(const Duration(seconds: 15));
    vm = await vmServiceConnectUri(
      uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
    );
    final isolates = (await vm.getVM()).isolates!;
    String? isolateId;
    for (final i in isolates) {
      if (await vm.isHttpProfilingAvailable(i.id!)) {
        isolateId = i.id;
        break;
      }
    }
    if (isolateId == null) throw StateError('No HTTP profiling isolate found');
    await vm.httpEnableTimelineLogging(isolateId, true);
    HttpProfileRequest? captured;
    for (var attempt = 0; attempt < 40; attempt++) {
      final profile = await vm.getHttpProfile(isolateId);
      for (final r in profile.requests) {
        if (r.isResponseComplete && r.uri.path.startsWith('/api/demo/')) {
          captured = await vm.getHttpProfileRequest(isolateId, r.id);
          break;
        }
      }
      if (captured != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (captured == null) throw StateError('No HTTP request captured');
    final decoder = DecryptionSession(
      DecryptionSettings(
        privateKeyPem: await File(
          await pemReady.future.timeout(const Duration(seconds: 15)),
        ).readAsString(),
      ),
    );
    final result = decoder.decode(
      utf8.decode(captured.requestBody!),
      utf8.decode(captured.responseBody!),
    );
    if (!result.request.decrypted ||
        !result.response.decrypted ||
        (result.response.value as Map)['ok'] != true) {
      throw StateError('The captured exchange did not decrypt');
    }
    stdout.writeln(
      'PASS: VM Service → HTTP profile → both bodies → RSA unwrap → AES → JSON.',
    );
  } finally {
    await vm?.dispose();
    child.kill(ProcessSignal.sigterm);
    await child.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        child.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await out.cancel();
    await err.cancel();
  }
}
