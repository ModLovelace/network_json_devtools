import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'inspector_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) {
    web.document.getElementById('loading')?.remove();
  });
  const demo = bool.fromEnvironment('NETWORK_JSON_DEMO');
  runApp(demo
      ? MaterialApp(debugShowCheckedModeBanner: false, theme: inspectorTheme(),
          home: const InspectorPage(demo: true))
      : DevToolsExtension(child: InspectorPage(serviceProvider: () => serviceManager.service)));
}

