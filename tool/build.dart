import 'dart:io';

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final source = Directory('${root.path}/packages/network_json_extension');
  String versionOf(String path) {
    final contents = File('${root.path}/$path').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(contents);
    if (match == null) throw StateError('Falta version en $path');
    return match.group(1)!;
  }

  final version = versionOf('pubspec.yaml');
  for (final path in [
    'extension/devtools/config.yaml',
    'packages/network_json_extension/pubspec.yaml',
  ]) {
    if (versionOf(path) != version) {
      throw StateError(
        'Sincroniza la versión $version en $path antes de compilar.',
      );
    }
  }
  if (!File(
    '${root.path}/README.md',
  ).readAsStringSync().contains('network_json_devtools: ^$version')) {
    throw StateError(
      'Actualiza el ejemplo de instalación del README a ^$version antes de compilar.',
    );
  }
  final demo = args.contains('--demo');
  final output = demo
      ? '${root.path}/build/demo'
      : '${root.path}/extension/devtools/build';
  Future<void> run(String executable, List<String> arguments) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: source.path,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) exit(code);
  }

  await run('flutter', ['pub', 'get']);
  await run('flutter', [
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn',
    '--pwa-strategy=none',
    '--output',
    output,
    if (demo) '--dart-define=NETWORK_JSON_DEMO=true',
  ]);
  if (!demo) {
    await run('dart', [
      'run',
      'devtools_extensions',
      'validate',
      '--package=${root.path}',
    ]);
  }
  stdout.writeln('Listo: $output');
}
