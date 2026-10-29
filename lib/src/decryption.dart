import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' show RSAKeyParser;
import 'package:pointycastle/export.dart';

enum KeyMode { rsaEnvelope, manualAes }

enum ByteFormat { hex, base64, utf8, byteArray }

class DecryptionFailure implements Exception {
  const DecryptionFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Never serialized: secrets live only in the extension's process memory.
class DecryptionSettings {
  const DecryptionSettings({
    this.mode = KeyMode.rsaEnvelope,
    this.privateKeyPem = '',
    this.aesKey = '',
    this.iv = '',
    this.keyFormat = ByteFormat.hex,
    this.ivFormat = ByteFormat.hex,
    this.cipherFormat = ByteFormat.hex,
    this.requestField = 'aesEncryptedData',
    this.responseField = 'data',
  });

  final KeyMode mode;
  final String privateKeyPem;
  final String aesKey;
  final String iv;
  final ByteFormat keyFormat;
  final ByteFormat ivFormat;
  final ByteFormat cipherFormat;
  final String requestField;
  final String responseField;
  bool get hasKey => mode == KeyMode.rsaEnvelope
      ? privateKeyPem.trim().isNotEmpty
      : aesKey.trim().isNotEmpty && iv.trim().isNotEmpty;
}

class PayloadView {
  const PayloadView(this.value, {this.decrypted = false, this.error});
  final Object? value;
  final bool decrypted;
  final String? error;
  String get pretty => value is String && error != null
      ? value as String
      : const JsonEncoder.withIndent('  ').convert(value);
}

class ExchangeView {
  const ExchangeView(this.request, this.response);
  final PayloadView request;
  final PayloadView response;
}

Uint8List decodeBytes(String text, ByteFormat format) {
  try {
    switch (format) {
      case ByteFormat.hex:
        final clean = text.trim().replaceFirst(RegExp(r'^0[xX]'), '')
            .replaceAll(RegExp(r'\s'), '');
        if (clean.isEmpty || clean.length.isOdd ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
          throw const FormatException();
        }
        return Uint8List.fromList([
          for (var i = 0; i < clean.length; i += 2)
            int.parse(clean.substring(i, i + 2), radix: 16),
        ]);
      case ByteFormat.base64:
        return base64.decode(base64.normalize(text.replaceAll(RegExp(r'\s'), '')));
      case ByteFormat.utf8:
        return Uint8List.fromList(utf8.encode(text));
      case ByteFormat.byteArray:
        final list = jsonDecode(text);
        if (list is! List || list.any((v) => v is! int || v < 0 || v > 255)) {
          throw const FormatException();
        }
        return Uint8List.fromList(list.cast<int>());
    }
  } catch (_) {
    throw const DecryptionFailure('El valor no coincide con la codificación seleccionada.');
  }
}

String encodeHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class DecryptionSession {
  DecryptionSession(this.settings) {
    if (!settings.hasKey) return;
    if (settings.mode == KeyMode.rsaEnvelope) {
      try {
        final parsed = RSAKeyParser().parse(settings.privateKeyPem.trim());
        if (parsed is! RSAPrivateKey) {
          throw const DecryptionFailure('Se necesita la llave privada RSA; la pública no sirve para descifrar.');
        }
        _rsa = parsed;
      } on DecryptionFailure {
        rethrow;
      } catch (_) {
        throw const DecryptionFailure('PEM inválido. Usa una llave privada RSA PKCS#1 o PKCS#8 sin contraseña.');
      }
    } else {
      _manualKey = decodeBytes(settings.aesKey, settings.keyFormat);
      _manualIv = decodeBytes(settings.iv, settings.ivFormat);
      _validateAes(_manualKey!, _manualIv!);
    }
  }

  final DecryptionSettings settings;
  RSAPrivateKey? _rsa;
  Uint8List? _manualKey;
  Uint8List? _manualIv;

  ExchangeView decode(String requestText, String responseText) {
    final request = _parse(requestText);
    final response = _parse(responseText);
    Uint8List? key;
    Uint8List? iv;
    String? keyError;
    final envelope = request.value is Map &&
        (request.value as Map).containsKey('rsaEncryptedAesKey') &&
        (request.value as Map).containsKey('rsaEncryptedIv');
    try {
      if (settings.mode == KeyMode.manualAes) {
        key = _manualKey;
        iv = _manualIv;
      } else if (envelope && _rsa != null) {
        final map = request.value as Map;
        key = decodeBytes(_unwrapRsa(map['rsaEncryptedAesKey']), ByteFormat.byteArray);
        iv = decodeBytes(_unwrapRsa(map['rsaEncryptedIv']), ByteFormat.byteArray);
        _validateAes(key, iv);
      }
    } on DecryptionFailure catch (e) {
      keyError = e.message;
    }
    final requestCipher = _field(request.value, settings.requestField);
    final responseCipher = _field(response.value, settings.responseField);
    // In RSA mode, only decode responses paired with a recognized envelope.
    // This avoids treating ordinary JSON {data: "..."} as ciphertext.
    final canDecodeResponse = envelope || settings.mode == KeyMode.manualAes;
    PayloadView decodeOne(PayloadView original, Object? cipher, bool eligible) {
      if (!eligible || cipher is! String || cipher.isEmpty) return original;
      if (keyError != null) return PayloadView(original.value, error: keyError);
      if (key == null || iv == null) {
        return PayloadView(original.value, error: settings.mode == KeyMode.rsaEnvelope
            ? 'Configura la llave privada RSA para descifrar esta petición.'
            : 'Configura la llave AES y el IV de esta petición.');
      }
      try {
        return PayloadView(_decryptAes(cipher, key, iv), decrypted: true);
      } on DecryptionFailure catch (e) {
        return PayloadView(original.value, error: e.message);
      }
    }
    return ExchangeView(
      decodeOne(request, requestCipher, true),
      decodeOne(response, responseCipher, canDecodeResponse),
    );
  }

  String _unwrapRsa(Object? value) {
    if (value is! String) {
      throw const DecryptionFailure('El sobre RSA de la petición está incompleto.');
    }
    try {
      // RSA-OAEP uses SHA-1 for both the digest and MGF1.
      final engine = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(_rsa!));
      final input = base64.decode(value);
      if (input.isEmpty || input.length % engine.inputBlockSize != 0) {
        throw const FormatException();
      }
      final result = BytesBuilder();
      for (var offset = 0; offset < input.length; offset += engine.inputBlockSize) {
        final block = Uint8List(engine.outputBlockSize);
        final length = engine.processBlock(input, offset, engine.inputBlockSize, block, 0);
        result.add(block.sublist(0, length));
      }
      return utf8.decode(result.takeBytes());
    } catch (_) {
      throw const DecryptionFailure('No se pudo abrir el sobre RSA. Comprueba la llave privada y el ambiente.');
    }
  }

  Object? _decryptAes(String cipherText, Uint8List key, Uint8List iv) {
    try {
      final bytes = decodeBytes(cipherText, settings.cipherFormat);
      if (bytes.isEmpty || bytes.length % 16 != 0) {
        throw const DecryptionFailure('El cuerpo cifrado no tiene una longitud válida para AES-CBC.');
      }
      final engine = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(key), iv));
      final padded = Uint8List(bytes.length);
      for (var i = 0; i < bytes.length; i += 16) {
        engine.processBlock(bytes, i, padded, i);
      }
      final count = PKCS7Padding().padCount(padded);
      return jsonDecode(utf8.decode(padded.sublist(0, padded.length - count)));
    } on DecryptionFailure {
      rethrow;
    } catch (_) {
      throw const DecryptionFailure('No se obtuvo JSON válido. Revisa la llave, el IV y la codificación del cuerpo.');
    }
  }
}

void _validateAes(Uint8List key, Uint8List iv) {
  if (![16, 24, 32].contains(key.length)) {
    throw const DecryptionFailure('La llave AES debe tener 16, 24 o 32 bytes.');
  }
  if (iv.length != 16) {
    throw const DecryptionFailure('El IV de AES-CBC debe tener exactamente 16 bytes.');
  }
}

PayloadView _parse(String text) {
  if (text.isEmpty) return const PayloadView(null);
  try {
    return PayloadView(jsonDecode(text));
  } catch (_) {
    return PayloadView(text, error: 'El cuerpo original no es JSON (o todavía está incompleto).');
  }
}

Object? _field(Object? value, String path) {
  if (path.trim().isEmpty) return value;
  for (final part in path.split('.')) {
    if (value is! Map) return null;
    value = value[part];
  }
  return value;
}
