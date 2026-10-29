import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// How a session obtains the AES key and initialization vector for an exchange.
enum KeyMode {
  /// Unwrap both values from the request using an RSA private key.
  rsaEnvelope,

  /// Use the AES key and initialization vector supplied in the settings.
  manualAes,
}

/// Supported encodings for keys, initialization vectors, and ciphertext.
enum ByteFormat {
  /// Two hexadecimal digits per byte, with optional whitespace or `0x` prefix.
  hex,

  /// Base64-encoded bytes.
  base64,

  /// Bytes obtained by encoding the supplied text as UTF-8.
  utf8,

  /// A JSON array of integers from 0 through 255, such as `[1, 2, 3]`.
  byteArray,
}

/// A configuration or decoding failure with a message safe to display.
///
/// Messages describe the failure without including the supplied key material.
class DecryptionFailure implements Exception {
  /// Creates a failure with a user-facing [message].
  const DecryptionFailure(this.message);

  /// The explanation of the failure, without secret values.
  final String message;

  /// Returns the user-facing explanation.
  @override
  String toString() => message;
}

/// Configuration for local RSA-OAEP/AES-CBC decoding of HTTP bodies.
///
/// In [KeyMode.rsaEnvelope], each request supplies its own wrapped AES key and
/// IV. In [KeyMode.manualAes], both values come from this configuration.
/// Settings are never serialized by this package; the extension keeps them
/// only in memory.
class DecryptionSettings {
  /// Creates settings with RSA envelopes and hexadecimal ciphertext by default.
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

  /// The source of the AES key and initialization vector.
  final KeyMode mode;

  /// An unencrypted RSA private key in PEM PKCS#1 or PKCS#8 format.
  final String privateKeyPem;

  /// The manually supplied AES key, encoded using [keyFormat].
  final String aesKey;

  /// The manually supplied initialization vector, encoded using [ivFormat].
  final String iv;

  /// The encoding of [aesKey] in manual mode.
  final ByteFormat keyFormat;

  /// The encoding of [iv] in manual mode.
  final ByteFormat ivFormat;

  /// The encoding of the encrypted body extracted from each JSON document.
  final ByteFormat cipherFormat;

  /// The dot-separated path to request ciphertext; empty selects the body.
  final String requestField;

  /// The dot-separated path to response ciphertext; empty selects the body.
  final String responseField;

  /// Whether the selected mode has nonempty key inputs, without validating them.
  bool get hasKey => mode == KeyMode.rsaEnvelope
      ? privateKeyPem.trim().isNotEmpty
      : aesKey.trim().isNotEmpty && iv.trim().isNotEmpty;
}

/// An original or decrypted body, with any decoding error kept alongside it.
class PayloadView {
  /// Creates a body view; [value] remains original when decoding fails.
  const PayloadView(this.value, {this.decrypted = false, this.error});

  /// Parsed JSON, or the original text when the input is not valid JSON.
  final Object? value;

  /// Whether [value] was successfully decrypted and parsed as JSON.
  final bool decrypted;

  /// A user-facing decoding error, or `null` when there is none.
  final String? error;

  /// Indented JSON, or unquoted original text when it could not be parsed.
  String get pretty => value is String && error != null
      ? value as String
      : const JsonEncoder.withIndent('  ').convert(value);
}

/// The decoded views of a request and its corresponding response.
class ExchangeView {
  /// Pairs the request and response body views.
  const ExchangeView(this.request, this.response);

  /// The request body, retaining its original value if decoding failed.
  final PayloadView request;

  /// The response body, using the same exchange's AES key and IV.
  final PayloadView response;
}

/// Decodes [text] using [format], without including its value in errors.
///
/// Throws [DecryptionFailure] for malformed encodings or invalid byte arrays.
Uint8List decodeBytes(String text, ByteFormat format) {
  try {
    switch (format) {
      case ByteFormat.hex:
        final clean = text
            .trim()
            .replaceFirst(RegExp(r'^0[xX]'), '')
            .replaceAll(RegExp(r'\s'), '');
        if (clean.isEmpty ||
            clean.length.isOdd ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
          throw const FormatException();
        }
        return Uint8List.fromList([
          for (var i = 0; i < clean.length; i += 2)
            int.parse(clean.substring(i, i + 2), radix: 16),
        ]);
      case ByteFormat.base64:
        return base64.decode(
          base64.normalize(text.replaceAll(RegExp(r'\s'), '')),
        );
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
    throw const DecryptionFailure(
      'El valor no coincide con la codificación seleccionada.',
    );
  }
}

/// Encodes bytes as lowercase hexadecimal, using two characters per byte.
String encodeHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Decodes HTTP request/response pairs using local RSA-OAEP and AES-CBC.
///
/// RSA envelopes use SHA-1 for OAEP and MGF1. AES bodies use PKCS7 padding and
/// must decode to UTF-8 JSON. A recovered key is used only for its own exchange.
class DecryptionSession {
  /// Validates [settings] and parses any supplied key.
  ///
  /// Throws [DecryptionFailure] for invalid PEM or manual AES parameters.
  /// Settings without a key are accepted so original bodies remain inspectable.
  DecryptionSession(this.settings) {
    if (!settings.hasKey) return;
    if (settings.mode == KeyMode.rsaEnvelope) {
      try {
        _rsa = _parseRsaPrivateKey(settings.privateKeyPem.trim());
      } on DecryptionFailure {
        rethrow;
      } catch (_) {
        throw const DecryptionFailure(
          'PEM inválido. Usa una llave privada RSA PKCS#1 o PKCS#8 sin contraseña.',
        );
      }
    } else {
      _manualKey = decodeBytes(settings.aesKey, settings.keyFormat);
      _manualIv = decodeBytes(settings.iv, settings.ivFormat);
      _validateAes(_manualKey!, _manualIv!);
    }
  }

  /// The configuration used throughout this session; it can contain secrets.
  final DecryptionSettings settings;
  RSAPrivateKey? _rsa;
  Uint8List? _manualKey;
  Uint8List? _manualIv;

  /// Parses and attempts to decrypt the two bodies of one HTTP exchange.
  ///
  /// In RSA mode, wrapped values are read from `rsaEncryptedAesKey` and
  /// `rsaEncryptedIv` in [requestText]. Failures preserve the original body
  /// and populate [PayloadView.error] instead of throwing.
  ExchangeView decode(String requestText, String responseText) {
    final request = _parse(requestText);
    final response = _parse(responseText);
    Uint8List? key;
    Uint8List? iv;
    String? keyError;
    final envelope =
        request.value is Map &&
        (request.value as Map).containsKey('rsaEncryptedAesKey') &&
        (request.value as Map).containsKey('rsaEncryptedIv');
    try {
      if (settings.mode == KeyMode.manualAes) {
        key = _manualKey;
        iv = _manualIv;
      } else if (envelope && _rsa != null) {
        final map = request.value as Map;
        key = decodeBytes(
          _unwrapRsa(map['rsaEncryptedAesKey']),
          ByteFormat.byteArray,
        );
        iv = decodeBytes(
          _unwrapRsa(map['rsaEncryptedIv']),
          ByteFormat.byteArray,
        );
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
        return PayloadView(
          original.value,
          error: settings.mode == KeyMode.rsaEnvelope
              ? 'Configura la llave privada RSA para descifrar esta petición.'
              : 'Configura la llave AES y el IV de esta petición.',
        );
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
      throw const DecryptionFailure(
        'El sobre RSA de la petición está incompleto.',
      );
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
      for (
        var offset = 0;
        offset < input.length;
        offset += engine.inputBlockSize
      ) {
        final block = Uint8List(engine.outputBlockSize);
        final length = engine.processBlock(
          input,
          offset,
          engine.inputBlockSize,
          block,
          0,
        );
        result.add(block.sublist(0, length));
      }
      return utf8.decode(result.takeBytes());
    } catch (_) {
      throw const DecryptionFailure(
        'No se pudo abrir el sobre RSA. Comprueba la llave privada y el ambiente.',
      );
    }
  }

  Object? _decryptAes(String cipherText, Uint8List key, Uint8List iv) {
    try {
      final bytes = decodeBytes(cipherText, settings.cipherFormat);
      if (bytes.isEmpty || bytes.length % 16 != 0) {
        throw const DecryptionFailure(
          'El cuerpo cifrado no tiene una longitud válida para AES-CBC.',
        );
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
      throw const DecryptionFailure(
        'No se obtuvo JSON válido. Revisa la llave, el IV y la codificación del cuerpo.',
      );
    }
  }
}

RSAPrivateKey _parseRsaPrivateKey(String pem) {
  final lines = pem
      .split(RegExp(r'\r\n?|\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.first == '-----BEGIN PUBLIC KEY-----' ||
      lines.first == '-----BEGIN RSA PUBLIC KEY-----') {
    throw const DecryptionFailure(
      'Se necesita la llave privada RSA; la pública no sirve para descifrar.',
    );
  }
  final pkcs8 = lines.first == '-----BEGIN PRIVATE KEY-----';
  final label = pkcs8 ? 'PRIVATE KEY' : 'RSA PRIVATE KEY';
  if (lines.length < 3 ||
      lines.first != '-----BEGIN $label-----' ||
      lines.last != '-----END $label-----') {
    throw const FormatException('Unsupported private key format');
  }
  ASN1Sequence sequence(Uint8List bytes) {
    final parser = ASN1Parser(bytes);
    final result = parser.nextObject() as ASN1Sequence;
    if (parser.hasNext()) throw const FormatException('Unexpected DER content');
    return result;
  }

  var fields = sequence(
    base64.decode(lines.sublist(1, lines.length - 1).join()),
  ).elements!;
  if (pkcs8) {
    final algorithm = (fields[1] as ASN1Sequence).elements!;
    final oid = algorithm.first as ASN1ObjectIdentifier;
    if ((fields.first as ASN1Integer).integer != BigInt.zero ||
        oid.objectIdentifierAsString != '1.2.840.113549.1.1.1') {
      throw const FormatException('Expected an RSA PrivateKeyInfo');
    }
    fields = sequence((fields[2] as ASN1OctetString).octets!).elements!;
  }
  if (fields.length != 9 ||
      fields.any((field) => field is! ASN1Integer) ||
      (fields.first as ASN1Integer).integer != BigInt.zero) {
    throw const FormatException('Expected a two-prime RSA private key');
  }
  BigInt integer(int index) => (fields[index] as ASN1Integer).integer!;
  return RSAPrivateKey(integer(1), integer(3), integer(4), integer(5));
}

void _validateAes(Uint8List key, Uint8List iv) {
  if (![16, 24, 32].contains(key.length)) {
    throw const DecryptionFailure('La llave AES debe tener 16, 24 o 32 bytes.');
  }
  if (iv.length != 16) {
    throw const DecryptionFailure(
      'El IV de AES-CBC debe tener exactamente 16 bytes.',
    );
  }
}

PayloadView _parse(String text) {
  if (text.isEmpty) return const PayloadView(null);
  try {
    return PayloadView(jsonDecode(text));
  } catch (_) {
    return PayloadView(
      text,
      error: 'El cuerpo original no es JSON (o todavía está incompleto).',
    );
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
