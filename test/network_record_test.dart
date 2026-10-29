import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

NetworkRecord record({String mime = 'application/json', bool error = false}) =>
    NetworkRecord(
      HttpProfileRequest(
        id: '1',
        isolateId: 'main',
        method: 'POST',
        uri: Uri.parse('https://example.test/items'),
        events: [],
        startTime: DateTime(2026, 10, 26),
        request: error
            ? HttpProfileRequestData.buildErrorRequest(
                error: 'connection failed',
              )
            : HttpProfileRequestData.buildSuccessfulRequest(
                cookies: [],
                headers: {
                  'Content-Type': [mime],
                },
              ),
        response: error
            ? null
            : HttpProfileResponseData(redirects: [], statusCode: 200),
      ),
    );

void main() {
  test('Combined filters use method, status, real MIME type and URL', () {
    final r = record();
    expect(r.matches('ITEMS', 'm:post s:200 t:json'), isTrue);
    expect(r.matches('', 'm:get'), isFalse);
    expect(record(mime: 'text/html').matches('', 't:json'), isFalse);
    expect(record(mime: 'text/html').type, 'html');
  });
  test('Failed requests have inspectable headers without throwing', () {
    final r = record(error: true);
    expect(r.requestHeaders, isEmpty);
    expect(r.complete, isTrue);
    expect(r.error, 'connection failed');
  });
  test('Request identity includes isolate to avoid collisions', () {
    expect(record().key, 'main/1');
  });
}
