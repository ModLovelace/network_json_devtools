import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Uso: dart run tool/install.dart /ruta/al/proyecto_flutter');
    exit(64);
  }
  final root = File.fromUri(Platform.script).parent.parent;
  final app = Directory(args.single).absolute;
  if (!File('${app.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('La carpeta indicada no contiene pubspec.yaml.'); exit(64);
  }
  if (!File('${root.path}/extension/devtools/build/main.dart.js').existsSync()) {
    stderr.writeln('Compila primero: dart run tool/build.dart'); exit(64);
  }
  // Let pub edit YAML safely; never embed or copy any application keys.
  final dependency = 'dev:network_json_devtools:${jsonEncode({'path': root.path})}';
  final process = await Process.start('flutter', ['pub', 'add', dependency],
    workingDirectory: app.path, mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) exit(code);
  stdout.writeln('Dependencia añadida. Reinicia DevTools y habilita network_json_devtools en Extensions.');
}
