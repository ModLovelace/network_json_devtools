import 'dart:convert';
import 'dart:io';
import '../example/support/sample_exchange.dart';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:test/test.dart';

void main() {
  final keys = SampleKeys.generate();
  final cases = [
    for (var i = 1; i <= 2; i++) SampleExchange(keys, sequence: i),
  ];
  final pem = keys.privatePem;
  final rsa = DecryptionSession(DecryptionSettings(privateKeyPem: pem));
  ExchangeView decode(DecryptionSession session, SampleExchange c) =>
      session.decode(jsonEncode(c.request), jsonEncode(c.response));

  test(
    'Generated RSA-OAEP/AES-CBC exchanges decode both JSON bodies and Unicode',
    () {
      for (final c in cases) {
        final result = decode(rsa, c);
        expect(result.request.error, isNull);
        expect(result.response.error, isNull);
        expect(result.request.decrypted, isTrue);
        expect(result.response.decrypted, isTrue);
        expect(result.request.value, c.requestPlain);
        expect(result.response.value, c.responsePlain);
      }
    },
  );

  test(
    'OpenSSL ciphertext is compatible with RSA-OAEP SHA-1 and AES-CBC',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'network-json-test-',
      );
      try {
        Future<void> openssl(List<String> args) async {
          final result = await Process.run(
            'openssl',
            args,
            workingDirectory: temporary.path,
          );
          expect(result.exitCode, 0, reason: result.stderr.toString());
        }

        await File('${temporary.path}/private.pem').writeAsString(pem);
        await openssl([
          'pkey',
          '-in',
          'private.pem',
          '-pubout',
          '-out',
          'public.pem',
        ]);
        final c = cases.first;
        final request = <String, String>{};
        for (final entry in {
          'rsaEncryptedAesKey': c.key,
          'rsaEncryptedIv': c.iv,
        }.entries) {
          await File(
            '${temporary.path}/plain',
          ).writeAsString(jsonEncode(entry.value));
          await openssl([
            'pkeyutl',
            '-encrypt',
            '-pubin',
            '-inkey',
            'public.pem',
            '-pkeyopt',
            'rsa_padding_mode:oaep',
            '-pkeyopt',
            'rsa_oaep_md:sha1',
            '-pkeyopt',
            'rsa_mgf1_md:sha1',
            '-in',
            'plain',
            '-out',
            'cipher',
          ]);
          request[entry.key] = base64Encode(
            await File('${temporary.path}/cipher').readAsBytes(),
          );
        }
        await File(
          '${temporary.path}/plain',
        ).writeAsString(jsonEncode(c.responsePlain));
        await openssl([
          'enc',
          '-aes-256-cbc',
          '-K',
          encodeHex(c.key),
          '-iv',
          encodeHex(c.iv),
          '-in',
          'plain',
          '-out',
          'cipher',
        ]);
        final response = {
          'data': encodeHex(
            await File('${temporary.path}/cipher').readAsBytes(),
          ),
        };
        expect(
          rsa.decode(jsonEncode(request), jsonEncode(response)).response.value,
          c.responsePlain,
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  test('Each request uses its own random AES key and IV', () {
    for (final i in [1, 0, 1]) {
      expect(decode(rsa, cases[i]).response.value, cases[i].responsePlain);
    }
    final mismatched = rsa.decode(
      jsonEncode(cases[0].request),
      jsonEncode(cases[1].response),
    );
    expect(mismatched.response.decrypted, isFalse);
    expect(mismatched.response.error, isNotNull);
  });

  test('PKCS#1 private PEM is supported', () {
    final session = DecryptionSession(
      DecryptionSettings(privateKeyPem: keys.privatePkcs1Pem),
    );
    expect(decode(session, cases[0]).request.value, cases[0].requestPlain);
  });

  test('Public key is rejected with an actionable message', () {
    expect(
      () =>
          DecryptionSession(DecryptionSettings(privateKeyPem: keys.publicPem)),
      throwsA(
        isA<DecryptionFailure>().having(
          (e) => e.message,
          'message',
          contains('privada'),
        ),
      ),
    );
  });

  test(
    'Without a key preserves ciphertext and gives configuration guidance',
    () {
      final result = decode(
        DecryptionSession(const DecryptionSettings()),
        cases[0],
      );
      expect(result.request.decrypted, isFalse);
      expect(result.response.value, cases[0].response);
      expect(result.response.error, contains('Configura'));
    },
  );

  test('Manual AES supports hex, Base64 and a Dart byte-list', () {
    final c = cases[0];
    final keyBytes = c.key;
    final ivBytes = c.iv;
    for (final f in [ByteFormat.hex, ByteFormat.base64, ByteFormat.byteArray]) {
      String encoded(List<int> b) => f == ByteFormat.hex
          ? encodeHex(b)
          : f == ByteFormat.base64
          ? base64Encode(b)
          : jsonEncode(b);
      final session = DecryptionSession(
        DecryptionSettings(
          mode: KeyMode.manualAes,
          aesKey: encoded(keyBytes),
          iv: encoded(ivBytes),
          keyFormat: f,
          ivFormat: f,
        ),
      );
      expect(decode(session, c).response.value, c.responsePlain);
    }
  });

  test('Manual AES supports Base64 ciphertext and nested field paths', () {
    final c = cases[0];
    final session = DecryptionSession(
      DecryptionSettings(
        mode: KeyMode.manualAes,
        aesKey: encodeHex(c.key),
        iv: encodeHex(c.iv),
        cipherFormat: ByteFormat.base64,
        requestField: 'payload.cipher',
        responseField: 'payload.cipher',
      ),
    );
    String body(String hex) => jsonEncode({
      'payload': {'cipher': base64Encode(decodeBytes(hex, ByteFormat.hex))},
    });
    final result = session.decode(
      body(c.request['aesEncryptedData']!),
      body(c.response['data'] as String),
    );
    expect(result.request.value, c.requestPlain);
    expect(result.response.value, c.responsePlain);
  });

  test('A JSON string body can be decoded using an empty field path', () {
    final c = cases[0];
    final session = DecryptionSession(
      DecryptionSettings(
        mode: KeyMode.manualAes,
        aesKey: encodeHex(c.key),
        iv: encodeHex(c.iv),
        requestField: '',
        responseField: '',
      ),
    );
    final result = session.decode(
      jsonEncode(c.request['aesEncryptedData']),
      jsonEncode(c.response['data']),
    );
    expect(result.response.value, c.responsePlain);
  });

  test(
    'Wrong key, broken padding and malformed RSA never return decrypted JSON',
    () {
      final c = cases[0];
      final session = DecryptionSession(
        DecryptionSettings(
          mode: KeyMode.manualAes,
          aesKey: encodeHex(cases[1].key),
          iv: encodeHex(c.iv),
        ),
      );
      expect(decode(session, c).response.decrypted, isFalse);
      final wrongRsa = Map<String, dynamic>.from(c.request)
        ..['rsaEncryptedAesKey'] = 'bad-ciphertext';
      final result = rsa.decode(jsonEncode(wrongRsa), jsonEncode(c.response));
      expect(result.request.error, contains('sobre RSA'));
      expect(result.response.error, isNot(contains(pem)));
      final badBody = rsa.decode(jsonEncode(c.request), '{"data":"ab"}');
      expect(badBody.response.decrypted, isFalse);
      expect(badBody.response.error, contains('longitud'));
    },
  );

  test('Plain JSON and non JSON bodies remain inspectable', () {
    final result = rsa.decode('{"plain":true}', '{"data":"ordinary text"}');
    expect(result.response.error, isNull);
    expect(result.response.value, {'data': 'ordinary text'});
    expect(result.response.decrypted, isFalse);
    final html = rsa.decode('', '<html>502 Bad Gateway</html>');
    expect(html.response.value, contains('502'));
    expect(html.response.error, isNotNull);
  });

  test('Malformed input and invalid key sizes never expose key material', () {
    for (final text in ['f', 'zz', '']) {
      expect(
        () => decodeBytes(text, ByteFormat.hex),
        throwsA(isA<DecryptionFailure>()),
      );
    }
    expect(
      () => decodeBytes('[256]', ByteFormat.byteArray),
      throwsA(isA<DecryptionFailure>()),
    );
    const secret = '112233';
    expect(
      () => DecryptionSession(
        const DecryptionSettings(
          mode: KeyMode.manualAes,
          aesKey: secret,
          iv: secret,
        ),
      ),
      throwsA(
        isA<DecryptionFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains(secret)),
        ),
      ),
    );
  });
}
