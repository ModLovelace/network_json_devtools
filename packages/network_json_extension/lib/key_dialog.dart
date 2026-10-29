import 'package:flutter/material.dart';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'theme.dart';
import 'key_file.dart';

Future<DecryptionSettings?> showKeyDialog(BuildContext context, DecryptionSettings current,
    {Future<String?> Function() pickKey = pickPrivateKey}) =>
    showDialog<DecryptionSettings>(context: context, barrierDismissible: false,
      builder: (_) => Theme(data: inspectorTheme(), child: KeyDialog(current: current, pickKey: pickKey)));

class KeyDialog extends StatefulWidget {
  const KeyDialog({super.key, required this.current, this.pickKey = pickPrivateKey});
  final DecryptionSettings current;
  final Future<String?> Function() pickKey;
  @override
  State<KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<KeyDialog> {
  late final TextEditingController pem, aes, iv, requestField, responseField;
  late KeyMode mode;
  late ByteFormat keyFormat, ivFormat, cipherFormat;
  String? error;
  bool showSecrets = false;
  bool loadingPem = false;
  @override
  void initState() {
    super.initState();
    final c = widget.current;
    mode = c.mode; keyFormat = c.keyFormat; ivFormat = c.ivFormat; cipherFormat = c.cipherFormat;
    pem = TextEditingController(text: c.privateKeyPem);
    aes = TextEditingController(text: c.aesKey);
    iv = TextEditingController(text: c.iv);
    requestField = TextEditingController(text: c.requestField);
    responseField = TextEditingController(text: c.responseField);
  }
  @override
  void dispose() {
    for (final c in [pem, aes, iv, requestField, responseField]) { c.dispose(); }
    super.dispose();
  }
  void apply() {
    if (loadingPem) return;
    final settings = DecryptionSettings(mode: mode, privateKeyPem: pem.text,
      aesKey: aes.text, iv: iv.text, keyFormat: keyFormat,
      ivFormat: ivFormat, cipherFormat: cipherFormat,
      requestField: requestField.text.trim(), responseField: responseField.text.trim());
    try {
      if (!settings.hasKey) throw const DecryptionFailure('Introduce una llave antes de aplicar la configuración.');
      DecryptionSession(settings);
      Navigator.of(context).pop(settings);
    } on DecryptionFailure catch (e) { setState(() => error = e.message); }
  }
  Future<void> loadPem() async {
    if (loadingPem) return;
    setState(() { loadingPem = true; error = null; });
    try {
      final text = await widget.pickKey();
      if (text == null || !mounted) return;
      if (text.trim().isEmpty) throw const DecryptionFailure('El archivo PEM está vacío.');
      // Keep the existing key until the replacement has been fully read and validated.
      DecryptionSession(DecryptionSettings(privateKeyPem: text));
      setState(() { pem.text = text; showSecrets = false; error = null; });
    } on DecryptionFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo leer el PEM. Selecciona una llave de texto de hasta 64 KB.');
    } finally {
      if (mounted) setState(() => loadingPem = false);
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !loadingPem, child: Dialog(
    insetPadding: const EdgeInsets.all(18),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 670, maxHeight: 800),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [const Icon(Icons.key_outlined, color: accent, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Configurar descifrado', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
            IconButton(tooltip: 'Cerrar', onPressed: loadingPem ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
          const SizedBox(height: 6),
          const Text('AES-CBC / PKCS7 · RSA-OAEP SHA-1', style: TextStyle(color: muted)),
          const SizedBox(height: 20),
          Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<KeyMode>(initialValue: mode, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Origen de la llave'),
              items: const [
                DropdownMenuItem(value: KeyMode.rsaEnvelope, child: Text('Sobre RSA de cada petición')),
                DropdownMenuItem(value: KeyMode.manualAes, child: Text('Llave AES + IV manuales')),
              ], onChanged: (v) => setState(() { mode = v!; error = null; })),
            const SizedBox(height: 18),
            if (mode == KeyMode.rsaEnvelope) ...[
              const Text('La llave privada RSA recupera la llave AES y el IV de los campos rsaEncryptedAesKey y rsaEncryptedIv del request.',
                style: TextStyle(color: muted, height: 1.6)),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: loadingPem ? null : loadPem,
                icon: loadingPem ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open_outlined, size: 17),
                label: Text(loadingPem ? 'Leyendo archivo PEM…' : 'Cargar archivo PEM')),
              const SizedBox(height: 12),
              if (pem.text.isNotEmpty && !showSecrets)
                Container(width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: lineColor), borderRadius: BorderRadius.circular(5)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('••••••••  Llave privada cargada', style: TextStyle(color: mint)),
                    SizedBox(height: 6),
                    Text('Pulsa «Aplicar y descifrar» para usarla.', style: TextStyle(color: muted, fontSize: 11)),
                  ]))
              else TextField(controller: pem, maxLines: 7, autocorrect: false, enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: const InputDecoration(labelText: 'Llave privada RSA · PEM',
                  alignLabelWithHint: true, hintText: '-----BEGIN PRIVATE KEY-----\n…\n-----END PRIVATE KEY-----')),
              if (pem.text.isNotEmpty) TextButton.icon(onPressed: () => setState(() => showSecrets = !showSecrets),
                icon: Icon(showSecrets ? Icons.visibility_off_outlined : Icons.edit_outlined, size: 16),
                label: Text(showSecrets ? 'Ocultar llave' : 'Editar llave')),
            ] else ...[
              const Text('Introduce la llave AES y el IV que corresponden a la petición seleccionada.', style: TextStyle(color: muted, height: 1.6)),
              const SizedBox(height: 14),
              TextField(controller: aes, obscureText: !showSecrets, autocorrect: false, enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Llave AES · 16, 24 o 32 bytes')),
              const SizedBox(height: 12),
              _format('Codificación de la llave', keyFormat, (v) => setState(() => keyFormat = v)),
              const SizedBox(height: 14),
              TextField(controller: iv, obscureText: !showSecrets, autocorrect: false, enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'IV · 16 bytes')),
              const SizedBox(height: 12),
              _format('Codificación del IV', ivFormat, (v) => setState(() => ivFormat = v)),
              TextButton.icon(onPressed: () => setState(() => showSecrets = !showSecrets),
                icon: Icon(showSecrets ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                label: Text(showSecrets ? 'Ocultar valores' : 'Mostrar valores')),
            ],
            const SizedBox(height: 18),
            _format('Codificación del texto cifrado', cipherFormat, (v) => setState(() => cipherFormat = v), bytesOnly: true),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: TextField(controller: requestField,
              decoration: const InputDecoration(labelText: 'Campo del request', helperText: 'Vacío = cuerpo completo'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: responseField,
                decoration: const InputDecoration(labelText: 'Campo del response', helperText: 'Admite rutas como payload.data')))]),
            const SizedBox(height: 16),
            const Text('La llave solo permanece en memoria. Al cerrar o recargar el panel tendrás que configurarla de nuevo.', style: TextStyle(color: muted, height: 1.6)),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 14),
              child: Text(error!, style: const TextStyle(color: Color(0xffffa89b)))),
          ]))),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
            TextButton(onPressed: loadingPem ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton.icon(onPressed: loadingPem ? null : apply, icon: const Icon(Icons.lock_open, size: 17), label: const Text('Aplicar y descifrar')),
          ]),
        ]))),
  ));

  Widget _format(String label, ByteFormat value, ValueChanged<ByteFormat> changed, {bool bytesOnly = false}) =>
      DropdownButtonFormField<ByteFormat>(key: ValueKey('$label-$value'), initialValue: value, isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final f in ByteFormat.values)
          if (!bytesOnly || [ByteFormat.hex, ByteFormat.base64].contains(f))
            DropdownMenuItem(value: f, child: Text(switch (f) {
              ByteFormat.hex => 'Hexadecimal', ByteFormat.base64 => 'Base64',
              ByteFormat.utf8 => 'Texto UTF-8', ByteFormat.byteArray => 'Lista de bytes [1, 2, …]',
            }))], onChanged: (v) => changed(v!));
}
