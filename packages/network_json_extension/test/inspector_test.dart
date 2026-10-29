import '../../../example/support/sample_exchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_json_extension/inspector_page.dart';
import 'package:network_json_extension/theme.dart';
import 'package:network_json_extension/key_dialog.dart';
import 'package:network_json_devtools/network_json_devtools.dart';

void main() {
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

  testWidgets('Shows decoded response, request and masks headers', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('JSON DESCIFRADO'), findsOneWidget);
    expect(
      find.textContaining('Example item', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('page:', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Headers'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bearer example-token', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('Mostrar sensibles'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bearer example-token', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forgetting the key removes decoded content immediately', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(
      find.byTooltip('Olvidar llave y borrar vistas descifradas'),
    );
    await tester.pumpAndSettle();
    expect(find.text('JSON DESCIFRADO'), findsNothing);
    expect(
      find.textContaining('Example item', findRichText: true),
      findsNothing,
    );
    expect(find.text('Configurar llave'), findsOneWidget);
  });

  testWidgets('Search, filters and clear update the request list', (
    tester,
  ) async {
    await open(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'no-match');
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);
    await tester.enterText(fields.first, '');
    await tester.enterText(fields.last, 'm:get s:200');
    await tester.pumpAndSettle();
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('POST'), findsNothing);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Esperando peticiones HTTP'), findsOneWidget);
    expect(find.text('Selecciona una petición'), findsOneWidget);
  });

  testWidgets('Narrow layout and configuration dialog fit without overflow', (
    tester,
  ) async {
    await open(tester, width: 390);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Configurar llave'));
    await tester.pumpAndSettle();
    expect(find.text('Configurar descifrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RSA configuration accepts the test PEM and preserves field defaults',
    (tester) async {
      DecryptionSettings? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: inspectorTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showKeyDialog(
                    context,
                    const DecryptionSettings(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Llave privada RSA · PEM');
      await tester.enterText(field, SampleKeys.generate().privatePem);
      await tester.tap(find.text('Aplicar y descifrar'));
      await tester.pumpAndSettle();
      expect(result?.hasKey, isTrue);
      expect(result?.mode, KeyMode.rsaEnvelope);
      expect(result?.requestField, 'aesEncryptedData');
      expect(result?.responseField, 'data');
      expect(tester.takeException(), isNull);
    },
  );
}
