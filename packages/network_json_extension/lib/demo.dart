import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:vm_service/vm_service.dart';

const demoSettings = DecryptionSettings(
  mode: KeyMode.manualAes,
  aesKey: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
  iv: '101112131415161718191a1b1c1d1e1f',
);

List<NetworkRecord> demoRecords() {
  final cipher = enc.Encrypter(
    enc.AES(enc.Key.fromBase16(demoSettings.aesKey), mode: enc.AESMode.cbc),
  );
  String encrypted(Object json) => cipher
      .encrypt(jsonEncode(json), iv: enc.IV.fromBase16(demoSettings.iv))
      .base16;
  final now = DateTime.now();
  return [
    for (var i = 0; i < 4; i++)
      (() {
        final start = now.subtract(Duration(seconds: i * 3 + 1));
        final end = start.add(Duration(milliseconds: [347, 82, 1048, 221][i]));
        final request = {
          'aesEncryptedData': encrypted({
            'id': 'sample-001',
            'page': 1,
            'limit': 20,
          }),
        };
        final response = {
          'data': encrypted({
            'ok': true,
            'message': 'Sample response',
            'data': {
              'id': 'sample-001',
              'name': 'Example item',
              'enabled': true,
              'items': [
                {'id': 101, 'name': 'Sample A', 'enabled': true},
                {'id': 102, 'name': 'Sample B', 'enabled': false},
              ],
              'total': 2,
            },
          }),
        };
        final profile = HttpProfileRequest(
          id: 'demo-$i',
          isolateId: 'demo',
          method: i == 1 ? 'GET' : 'POST',
          uri: Uri.parse(
            'https://api.example.test/v1/${['items/1', 'items', 'items/search', 'status'][i]}',
          ),
          startTime: start,
          endTime: end,
          events: [],
          request: HttpProfileRequestData.buildSuccessfulRequest(
            cookies: [],
            headers: {
              'content-type': ['application/json'],
              'authorization': ['Bearer example-token'],
            },
          ),
          response: HttpProfileResponseData(
            statusCode: 200,
            startTime: start,
            endTime: end,
            headers: {
              'content-type': ['application/json; charset=utf-8'],
            },
            redirects: [],
          ),
          requestBody: Uint8List.fromList(utf8.encode(jsonEncode(request))),
          responseBody: Uint8List.fromList(utf8.encode(jsonEncode(response))),
        );
        return NetworkRecord(profile)..detail = profile;
      })(),
  ];
}
