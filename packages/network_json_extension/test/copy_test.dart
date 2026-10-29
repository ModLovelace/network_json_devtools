import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_json_extension/demo.dart';
import 'package:network_json_extension/inspector_page.dart';
import 'package:network_json_extension/theme.dart';

void main() {
  final sampleUrl = demoRecords().first.url;
  late List<String> copied;
  var denyClipboard = false;

  setUp(() {
    copied = [];
    denyClipboard = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (denyClipboard) {
              throw PlatformException(code: 'clipboard-denied');
            }
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> open(WidgetTester tester, {double width = 1280}) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: inspectorTheme(),
        home: const InspectorPage(demo: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> contextMenu(WidgetTester tester, Finder cell) async {
    await tester.tap(
      cell,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Context menu copies the full URL only after clicking Copy', (
    tester,
  ) async {
    await open(tester);
    final address = find.text(sampleUrl);
    expect(tester.widget<Text>(address).overflow, TextOverflow.ellipsis);
    await contextMenu(tester, address);
    expect(find.text('Copiar URL'), findsOneWidget);
    expect(copied, isEmpty);
    await tester.tap(find.text('Copiar URL'));
    await tester.pumpAndSettle();
    expect(copied, [sampleUrl]);
    expect(copied.single, contains('?fields=id,name,enabled&include=items'));
    expect(find.text('Copiar URL'), findsNothing);
    expect(find.text('Copiado al portapapeles'), findsOneWidget);
  });

  testWidgets(
    'Right click selects the clicked request for copying the exchange',
    (tester) async {
      await open(tester);
      final otherUrl = demoRecords()[1].url;
      await contextMenu(tester, find.text(otherUrl));
      await tester.tap(find.text('Copiar URL'));
      await tester.pumpAndSettle();
      expect(copied.single, otherUrl);
      await tester.tap(find.text('Copiar todo'));
      await tester.pumpAndSettle();
      expect((jsonDecode(copied.last) as Map)['url'], otherUrl);
    },
  );

  for (final entry in {
    'Copiar método': 'POST',
    'Copiar estado': '200',
    'Copiar tipo': 'json',
    'Copiar duración': '347 ms',
  }.entries) {
    testWidgets('${entry.key} copies the clicked cell value', (tester) async {
      await open(tester);
      await contextMenu(tester, find.text(entry.value).first);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(copied, [entry.value]);
    });
  }

  testWidgets('Dismissing the context menu does not copy anything', (
    tester,
  ) async {
    await open(tester);
    await contextMenu(tester, find.text(sampleUrl));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copiar URL'), findsNothing);
    expect(copied, isEmpty);
  });

  testWidgets('Long press opens the copy menu on a narrow layout', (
    tester,
  ) async {
    await open(tester, width: 390);
    await tester.longPress(find.text(sampleUrl));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar URL'));
    await tester.pumpAndSettle();
    expect(copied, [sampleUrl]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Copy all includes URL and both decrypted JSON bodies', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Copiar todo'));
    await tester.pumpAndSettle();
    final exchange = jsonDecode(copied.single) as Map;
    expect(exchange.keys, unorderedEquals(['url', 'request', 'response']));
    expect(exchange['url'], sampleUrl);
    expect(exchange['request'], {'id': 'sample-001', 'page': 1, 'limit': 20});
    expect(exchange['response']['data']['name'], 'Example item');
  });

  testWidgets('Copy all respects the Original view', (tester) async {
    await open(tester);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar todo'));
    await tester.pumpAndSettle();
    final exchange = jsonDecode(copied.single) as Map;
    final sample = demoRecords().first;
    expect(exchange['request'], jsonDecode(sample.requestText));
    expect(exchange['response'], jsonDecode(sample.responseText));
    expect(exchange['response']['data'], isA<String>());
  });

  testWidgets('Forgetting the key prevents copying cached decrypted bodies', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(
      find.byTooltip('Olvidar llave y borrar vistas descifradas'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar todo'));
    await tester.pumpAndSettle();
    final exchange = jsonDecode(copied.single) as Map;
    expect(exchange['request']['aesEncryptedData'], isA<String>());
    expect(exchange['response']['data'], isA<String>());
    expect(copied.single, isNot(contains('Example item')));
  });

  testWidgets('Clipboard denial shows an error instead of success', (
    tester,
  ) async {
    denyClipboard = true;
    await open(tester);
    await tester.tap(find.text('Copiar todo'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(
      find.textContaining('El navegador no permitió copiar.'),
      findsOneWidget,
    );
    expect(find.text('Copiado al portapapeles'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
