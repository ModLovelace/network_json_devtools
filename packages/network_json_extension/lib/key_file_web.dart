import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Reads a user-selected local file. No upload or persistence is involved.
Future<String?> pickPrivateKey() async {
  final input = web.HTMLInputElement()..type = 'file'..accept = '.pem,.key,text/plain';
  input.style.display = 'none';
  web.document.body!.append(input);
  final done = Completer<String?>();
  final changed = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) { done.complete(null); return; }
    if (file.size > 65536) {
      done.completeError(const FormatException('El PEM supera el tamaño permitido.'));
      return;
    }
    file.text().toDart.then((text) { if (!done.isCompleted) done.complete(text.toDart); },
      onError: (Object _) { if (!done.isCompleted) done.completeError(const FormatException('No se pudo leer el PEM.')); });
  }).toJS;
  final cancelled = ((web.Event _) { if (!done.isCompleted) done.complete(null); }).toJS;
  input.addEventListener('change', changed);
  input.addEventListener('cancel', cancelled);
  try { input.click(); return await done.future; }
  finally {
    input.removeEventListener('change', changed);
    input.removeEventListener('cancel', cancelled);
    input.remove();
  }
}
