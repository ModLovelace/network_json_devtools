// Disposable sample data. Generate keys for each run; never use them in an app.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:network_json_devtools/network_json_devtools.dart'
    show encodeHex;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

Uint8List sampleBytes(int count) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(count, (_) => random.nextInt(256)));
}

String _pem(String label, List<int> bytes) {
  final encoded = base64Encode(bytes);
  final lines = [
    for (var i = 0; i < encoded.length; i += 64)
      encoded.substring(i, min(i + 64, encoded.length)),
  ];
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
}

class SampleKeys {
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;

  SampleKeys._(this.publicKey, this.privateKey);

  factory SampleKeys.generate() {
    final random = FortunaRandom()..seed(KeyParameter(sampleBytes(32)));
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    return SampleKeys._(pair.publicKey, pair.privateKey);
  }

  ASN1Sequence get _privateSequence {
    final p = privateKey.p!;
    final q = privateKey.q!;
    final d = privateKey.privateExponent!;
    return ASN1Sequence(
      elements: [
        BigInt.zero,
        privateKey.modulus!,
        publicKey.publicExponent!,
        d,
        p,
        q,
        d % (p - BigInt.one),
        d % (q - BigInt.one),
        q.modInverse(p),
      ].map(ASN1Integer.new).toList(),
    );
  }

  String get privatePkcs1Pem =>
      _pem('RSA PRIVATE KEY', _privateSequence.encode());
  String get privatePem => _pem(
    'PRIVATE KEY',
    ASN1PrivateKeyInfo.fromPkcs1Rsa(_privateSequence).encode(),
  );
  String get publicPem => _pem(
    'RSA PUBLIC KEY',
    ASN1Sequence(
      elements: [
        ASN1Integer(publicKey.modulus!),
        ASN1Integer(publicKey.publicExponent!),
      ],
    ).encode(),
  );

  String wrap(List<int> bytes) {
    final rsa = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return base64Encode(
      rsa.process(Uint8List.fromList(utf8.encode(jsonEncode(bytes)))),
    );
  }
}

class SampleExchange {
  final Uint8List key = sampleBytes(32);
  final Uint8List iv = sampleBytes(16);
  final Map<String, Object> requestPlain;
  final Map<String, Object> responsePlain;
  late final Map<String, String> request;
  late final Map<String, Object> response;

  SampleExchange(SampleKeys keys, {int sequence = 1})
    : requestPlain = {
        'id': sequence,
        'text': 'Example · áéí · 漢字 · 🙂',
        'enabled': true,
      },
      responsePlain = {
        'ok': true,
        'item': {'id': sequence, 'name': 'Example item'},
      } {
    request = {
      'rsaEncryptedAesKey': keys.wrap(key),
      'rsaEncryptedIv': keys.wrap(iv),
      'aesEncryptedData': encrypt(requestPlain),
    };
    response = {'ok': true, 'data': encrypt(responsePlain)};
  }

  String encrypt(Object value) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters(
              ParametersWithIV(KeyParameter(key), iv),
              null,
            ),
          );
    return encodeHex(
      cipher.process(Uint8List.fromList(utf8.encode(jsonEncode(value)))),
    );
  }
}
