import 'dart:async';
import '../../../example/support/sample_exchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:network_json_extension/key_dialog.dart';
import 'package:network_json_extension/theme.dart';

void main() {
  final testPem = SampleKeys.generate().privatePem;

  testWidgets('Native PEM selection cannot dismiss the dialog before Apply', (
    tester,
  ) async {
    final selected = Completer<String?>();
    DecryptionSettings? applied;
    await tester.pumpWidget(
      MaterialApp(
        theme: inspectorTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                applied = await showKeyDialog(
                  context,
                  const DecryptionSettings(),
                  pickKey: () => selected.future,
                );
              },
              child: const Text('Configure'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar archivo PEM'));
    await tester.pump();

    // Focus/pointer changes around a native picker must not pop the route.
    await tester.tapAt(const Offset(3, 3));
    await tester.pump(const Duration(milliseconds: 300));
    selected.complete(testPem);
    await tester.pumpAndSettle();
    expect(find.text('Configurar descifrado'), findsOneWidget);
    expect(find.textContaining('Llave privada cargada'), findsOneWidget);
    expect(applied, isNull);

    // The imported value also survives clicking outside after reading it.
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar y descifrar'));
    await tester.pumpAndSettle();
    expect(applied?.privateKeyPem, testPem);
    expect(applied?.hasKey, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape from a file picker does not close configuration', (
    tester,
  ) async {
    final selected = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        theme: inspectorTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showKeyDialog(
                context,
                const DecryptionSettings(),
                pickKey: () => selected.future,
              ),
              child: const Text('Configure'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar archivo PEM'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    selected.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Configurar descifrado'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Configurar descifrado'), findsNothing);
  });

  for (final replacement in <String?>[null, 'not a private PEM']) {
    testWidgets(
      '${replacement == null ? 'Cancelling' : 'Invalid'} PEM replacement preserves the current key',
      (tester) async {
        DecryptionSettings? applied;
        await tester.pumpWidget(
          MaterialApp(
            theme: inspectorTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    applied = await showKeyDialog(
                      context,
                      DecryptionSettings(privateKeyPem: testPem),
                      pickKey: () async => replacement,
                    );
                  },
                  child: const Text('Configure'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Configure'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cargar archivo PEM'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Llave privada cargada'), findsOneWidget);
        await tester.tap(find.text('Aplicar y descifrar'));
        await tester.pumpAndSettle();
        expect(applied?.privateKeyPem, testPem);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
