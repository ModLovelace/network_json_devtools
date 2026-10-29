import 'dart:io';

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final source = Directory('${root.path}/packages/network_json_extension');
  final demo = args.contains('--demo');
  final output = demo
      ? '${root.path}/build/demo'
      : '${root.path}/extension/devtools/build';
  if (!demo) {
    // Pub uses doc/; mirror the maintained documentation from docs/.
    const publicDocuments = ['FORMATO_CIFRADO.md', 'VALIDACION.md'];
    for (final relative in publicDocuments) {
      final destination = File('${root.path}/doc/$relative');
      await destination.parent.create(recursive: true);
      await File('${root.path}/docs/$relative').copy(destination.path);
    }
  }
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
