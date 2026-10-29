import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:vm_service/vm_service.dart';
import 'capture_controller.dart';
import 'demo.dart';
import 'json_tree.dart';
import 'key_dialog.dart';
import 'theme.dart';

class InspectorPage extends StatefulWidget {
  const InspectorPage({super.key, this.demo = false, this.serviceProvider});
  final bool demo;
  final VmService? Function()? serviceProvider;
  @override
  State<InspectorPage> createState() => _InspectorPageState();
}

class _InspectorPageState extends State<InspectorPage> {
  late final CaptureController capture;
  DecryptionSettings settings = const DecryptionSettings();
  late DecryptionSession session;
  ExchangeView? _cachedView;
  Object? _cachedDetail;
  final searchController = TextEditingController();
  final filterController = TextEditingController();
  final tableScroll = ScrollController();
  int tab = 3;
  bool decrypted = true;
  bool source = false;
  bool showSensitive = false;
  bool newestFirst = true;
  double split = .46;

  @override
  void initState() {
    super.initState();
    capture = CaptureController(() => widget.serviceProvider?.call());
    if (widget.demo) {
      settings = demoSettings;
      final rows = demoRecords();
      for (final r in rows) { capture.records[r.key] = r; }
      capture.selectedKey = rows.first.key;
    }
    session = DecryptionSession(settings);
    capture.addListener(_refresh);
    if (!widget.demo) capture.start();
  }

  void _refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    capture.removeListener(_refresh);
    capture.dispose();
    searchController.dispose(); filterController.dispose(); tableScroll.dispose();
    super.dispose();
  }

  ExchangeView _decoded(NetworkRecord record) {
    if (!identical(_cachedDetail, record.detail) || _cachedView == null) {
      _cachedDetail = record.detail;
      _cachedView = session.decode(record.requestText, record.responseText);
    }
    return _cachedView!;
  }

  Future<void> _configure() async {
    final next = await showKeyDialog(context, settings);
    if (next == null || !mounted) return;
    setState(() {
      settings = next; session = DecryptionSession(next);
      _cachedView = null; decrypted = true;
    });
  }

  void _forget() {
    setState(() {
      settings = const DecryptionSettings(); session = DecryptionSession(settings);
      _cachedView = null; _cachedDetail = null;
    });
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copiado al portapapeles'), duration: Duration(seconds: 2)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El navegador no permitió copiar. Usa la vista Texto para seleccionar el contenido.')));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: inspectorTheme(),
    child: Scaffold(body: Column(children: [
      _heading(), _toolbar(),
      if (widget.demo) _notice('Vista de demostración · Datos ficticios · Llave AES de prueba', Icons.science_outlined, mint),
      if (!widget.demo && capture.message != null) _notice(capture.message!, Icons.info_outline, muted),
      Expanded(child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 800) {
          return Column(children: [SizedBox(height: math.min(220, box.maxHeight * .4), child: _table()),
            const Divider(), Expanded(child: _details())]);
        }
        return Row(children: [SizedBox(width: box.maxWidth * split, child: _table()),
          MouseRegion(cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (e) => setState(() => split = (split + e.delta.dx / box.maxWidth).clamp(.27, .7)),
              child: Container(width: 7, decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: lineColor), right: BorderSide(color: lineColor)))))),
          Expanded(child: _details())]);
      })),
      _footer(),
    ])));

  Widget _heading() => Container(height: 49, padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: lineColor))),
    child: Row(children: [const Icon(Icons.hub_outlined, size: 20, color: accent), const SizedBox(width: 10),
      const Text('Network JSON', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(width: 12),
      if (MediaQuery.sizeOf(context).width > 540 && widget.demo) const SmallTag('DEMO', color: mint)
      else if (MediaQuery.sizeOf(context).width > 540) Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(
        shape: BoxShape.circle, color: capture.connected ? mint : muted)), const SizedBox(width: 6),
        Text(capture.connected ? 'Conectado' : 'Sin conexión', style: const TextStyle(fontSize: 11, color: muted))]),
      const Spacer(),
      if (MediaQuery.sizeOf(context).width < 540)
        IconButton(tooltip: 'Configurar llave', onPressed: _configure, icon: const Icon(Icons.key_outlined, color: accent))
      else TextButton.icon(onPressed: _configure,
        icon: Icon(settings.hasKey ? Icons.lock_open_outlined : Icons.key_outlined, size: 16),
        label: Text(settings.hasKey ? 'Llave configurada' : 'Configurar llave', style: const TextStyle(fontSize: 12))),
      if (settings.hasKey) IconButton(tooltip: 'Olvidar llave y borrar vistas descifradas', onPressed: _forget,
        icon: const Icon(Icons.key_off_outlined)),
    ]));

  Widget _toolbar() => LayoutBuilder(builder: (context, box) {
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(tooltip: capture.recording ? 'Pausar captura' : 'Reanudar captura',
        onPressed: capture.toggleRecording,
        icon: Icon(capture.recording ? Icons.stop_circle_outlined : Icons.play_circle_outline,
          color: capture.recording ? const Color(0xffed8b81) : mint, size: 21)),
      TextButton.icon(onPressed: () { capture.clear(); _cachedView = null; _cachedDetail = null; },
        icon: const Icon(Icons.block, size: 16), label: const Text('Clear', style: TextStyle(fontSize: 12))),
    ]);
    Widget search() => SizedBox(height: 32, child: TextField(controller: searchController,
      onChanged: (_) => setState(() {}), decoration: const InputDecoration(
        hintText: 'Search · URL, método o estado', prefixIcon: Icon(Icons.search, size: 16),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 7))));
    Widget filter() => SizedBox(height: 32, child: TextField(controller: filterController,
      onChanged: (_) => setState(() {}), decoration: InputDecoration(
        hintText: 'Filter · m:post s:200', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        suffixIcon: Tooltip(message: 'Filtros: m:post, s:200, t:json o parte de la URL. Combina filtros con espacios.',
          child: const Icon(Icons.filter_alt_outlined, size: 16)))));
    return Container(padding: const EdgeInsets.fromLTRB(7, 9, 12, 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: lineColor))),
      child: box.maxWidth > 720
        ? Row(children: [actions, const SizedBox(width: 8), Expanded(child: search()),
            const SizedBox(width: 8), Expanded(child: filter())])
        : Column(children: [Row(children: [actions, const SizedBox(width: 8), Expanded(child: search())]),
            const SizedBox(height: 8), filter()]));
  });

  Widget _notice(String text, IconData icon, Color color) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    color: color.withValues(alpha: .05), child: Row(children: [Icon(icon, size: 15, color: color),
      const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11, height: 1.5)))]));

  Widget _table() {
    final rows = capture.records.values.where((r) => r.matches(searchController.text, filterController.text)).toList()
      ..sort((a, b) => newestFirst ? b.profile.startTime.compareTo(a.profile.startTime) : a.profile.startTime.compareTo(b.profile.startTime));
    return LayoutBuilder(builder: (context, box) {
      final width = math.max(590.0, box.maxWidth);
      final widths = [66.0, width - 66 - 55 - 48 - 76 - 105, 55.0, 48.0, 76.0, 105.0];
      Widget cells(List<Widget> values, {bool header = false}) => Row(children: [
        for (var i = 0; i < values.length; i++) Container(width: widths[i], height: header ? 31 : 30,
          alignment: i >= 2 ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: lineColor.withValues(alpha: .6)))),
          child: values[i]),
      ]);
      return Scrollbar(controller: tableScroll, thumbVisibility: box.maxWidth < width,
        child: SingleChildScrollView(controller: tableScroll, scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, height: box.maxHeight, child: Column(children: [
            Container(color: const Color(0xff333333), child: DefaultTextStyle(
              style: const TextStyle(fontSize: 11, color: Color(0xffbcbcc3), fontWeight: FontWeight.w600),
              child: cells([const Text('Method'), const Text('Address'), const Text('Status'), const Text('Type'),
                const Text('Duration'), InkWell(onTap: () => setState(() => newestFirst = !newestFirst),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Flexible(child: Text('Timestamp', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Icon(newestFirst ? Icons.arrow_downward : Icons.arrow_upward, size: 12, color: muted)]))], header: true))),
            const Divider(),
            Expanded(child: rows.isEmpty ? _emptyTable() : ListView.builder(itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final selected = capture.selectedKey == r.key;
                return Material(color: selected ? const Color(0xff4b4857)
                    : i.isEven ? const Color(0xff2e2e2e) : background,
                  child: InkWell(onTap: () { _cachedView = null; capture.select(r); },
                    child: DefaultTextStyle(style: const TextStyle(fontSize: 11, color: Color(0xffceced4)),
                      child: cells([
                        Text(r.method, style: TextStyle(color: r.method == 'GET' ? mint : const Color(0xffa4bddd))),
                        Tooltip(message: r.url, child: Text(r.url, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(r.error != null ? 'Error' : '${r.status ?? '…'}', style: TextStyle(color: r.error != null || (r.status ?? 0) >= 400 ? const Color(0xffeea39b) : mint)),
                        Text(r.type, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted)),
                        Text(_duration(r.duration)), Text(_time(r.profile.startTime)),
                      ]))));
              })),
          ]))));
    });
  }

  Widget _emptyTable() => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.swap_vert, color: muted, size: 27),
      const SizedBox(height: 12), Text(capture.records.isEmpty ? 'Esperando peticiones HTTP' : 'Sin coincidencias',
        style: const TextStyle(fontSize: 13)), const SizedBox(height: 7),
      Text(capture.records.isEmpty ? 'Abre el panel antes de ejecutar una petición en la app.' : 'Prueba otra búsqueda o elimina los filtros.',
        style: const TextStyle(color: muted, fontSize: 11), textAlign: TextAlign.center)])));

  Widget _details() {
    final r = capture.selected;
    if (r == null) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.data_object, size: 38, color: lineColor), SizedBox(height: 15),
      Text('Selecciona una petición', style: TextStyle(fontSize: 14)), SizedBox(height: 8),
      Text('Inspecciona el request y el response en JSON.', style: TextStyle(color: muted, fontSize: 12))]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 39, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: lineColor))),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final (i, title) in ['Overview', 'Headers', 'Request', 'Response'].indexed)
            InkWell(onTap: () => setState(() => tab = i), child: Container(
              height: 39, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == i ? accent : Colors.transparent, width: 3))),
              child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: tab == i ? const Color(0xffe6dff8) : muted)))),
        ]))),
      if (capture.loadingDetail) const LinearProgressIndicator(minHeight: 2, color: accent),
      if (r.detailError != null) _notice(r.detailError!, Icons.error_outline, orange),
      Expanded(child: tab == 0 ? _overview(r) : tab == 1 ? _headers(r) : _body(r)),
    ]);
  }

  Widget _overview(NetworkRecord r) => SingleChildScrollView(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('GENERAL', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.4)), const SizedBox(height: 18),
      _property('Request URL', r.url), _property('Request method', r.method),
      _property('Status code', '${r.status ?? 'Pending'}'),
      _property('Duration', _duration(r.duration)), _property('Timestamp', r.profile.startTime.toLocal().toIso8601String()),
      _property('Request size', '${r.detail?.requestBody?.length ?? 0} bytes'),
      _property('Response size', '${r.detail?.responseBody?.length ?? 0} bytes'),
      _property('Isolate', r.profile.isolateId),
      if (r.error != null) _notice(r.error!, Icons.error_outline, orange),
      const SizedBox(height: 20), const Divider(), const SizedBox(height: 18),
      const Text('DESCIFRADO LOCAL', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.4)), const SizedBox(height: 16),
      _property('Algoritmo', 'AES-CBC · PKCS7'),
      _property('Origen', settings.mode == KeyMode.rsaEnvelope ? 'Sobre RSA-OAEP SHA-1 de cada request' : 'Llave AES e IV manuales'),
      _property('Llave', settings.hasKey ? 'Configurada · solo en memoria' : 'Sin configurar'),
    ]));

  Widget _property(String name, String value) => Padding(padding: const EdgeInsets.only(bottom: 15),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 118,
      child: Text(name, style: const TextStyle(color: muted, fontSize: 11))),
      Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, height: 1.5)))]));

  Map<String, dynamic> _safeHeaders(Map<String, dynamic> headers) => {
    for (final e in headers.entries) e.key: !showSensitive && RegExp(
      r'authorization|cookie|token|api[-_]?key|secret', caseSensitive: false).hasMatch(e.key) ? '••••••••' : e.value,
  };

  Widget _headers(NetworkRecord r) => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [TextButton.icon(onPressed: () => setState(() => showSensitive = !showSensitive),
        icon: Icon(showSensitive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 15),
        label: Text(showSensitive ? 'Ocultar sensibles' : 'Mostrar sensibles', style: const TextStyle(fontSize: 11))),
        const Spacer(), IconButton(tooltip: 'Copiar headers visibles', onPressed: () => _copy(const JsonEncoder.withIndent('  ').convert({
          'request': _safeHeaders(r.requestHeaders), 'response': _safeHeaders(r.responseHeaders)})), icon: const Icon(Icons.copy_outlined))])),
    const Divider(),
    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      JsonTree(value: _safeHeaders(r.requestHeaders), label: 'Request headers'), const SizedBox(height: 20),
      JsonTree(value: _safeHeaders(r.responseHeaders), label: 'Response headers'),
    ]))),
  ]);

  Widget _body(NetworkRecord r) {
    final decoded = _decoded(r);
    final rawText = tab == 2 ? r.requestText : r.responseText;
    final decodedPayload = tab == 2 ? decoded.request : decoded.response;
    final rawPayload = DecryptionSession(const DecryptionSettings()).decode(rawText, '');
    final payload = decrypted ? decodedPayload : rawPayload.request;
    final available = rawText.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 42, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        const SizedBox(width: 12),
        DropdownButton<bool>(value: decrypted, underline: const SizedBox.shrink(), isDense: true,
          style: const TextStyle(color: Color(0xffd8d8df), fontSize: 11),
          items: const [DropdownMenuItem(value: true, child: Text('Descifrado')),
            DropdownMenuItem(value: false, child: Text('Original'))],
          onChanged: (v) => setState(() => decrypted = v!)),
        const SizedBox(width: 14),
        if (decrypted && payload.decrypted) const SmallTag('JSON DESCIFRADO', color: mint)
        else if (available && !decrypted) const SmallTag('ORIGINAL', color: muted),
        const SizedBox(width: 16),
        IconButton(tooltip: source ? 'Ver árbol JSON' : 'Ver texto JSON', onPressed: () => setState(() => source = !source),
          icon: Icon(source ? Icons.account_tree_outlined : Icons.code, color: source ? accent : muted)),
        IconButton(tooltip: 'Copiar contenido visible', onPressed: available ? () => _copy(
          decrypted ? payload.pretty : rawText) : null, icon: const Icon(Icons.copy_outlined)),
      ]))),
      const Divider(),
      if (decrypted && payload.error != null && available) _notice(payload.error!, Icons.lock_outline, orange),
      Expanded(child: !available ? Center(child: Text(
        capture.loadingDetail ? 'Cargando cuerpo…' : r.complete ? 'Sin cuerpo registrado' : 'Esperando cuerpo de la petición…',
        style: const TextStyle(color: muted, fontSize: 12))) : SelectionArea(
          child: SingleChildScrollView(padding: const EdgeInsets.all(18),
            child: source ? SelectableText(decrypted ? payload.pretty : rawPayload.request.pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.8, color: orange))
            : JsonTree(key: ValueKey('${r.key}-$tab-$decrypted-${settings.hashCode}'), value: payload.value)))),
    ]);
  }

  Widget _footer() => Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: const BoxDecoration(color: Color(0xff252525), border: Border(top: BorderSide(color: lineColor))),
    child: Row(children: [Icon(capture.recording ? Icons.circle : Icons.pause_circle_outline,
      size: 7, color: capture.recording ? mint : muted), const SizedBox(width: 7),
      Expanded(child: Text('${capture.records.length} peticiones · ${capture.recording ? 'Capturando' : 'En pausa'}',
        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10))),
      if (capture.evicted > 0) Text(' · ${capture.evicted} anteriores descartadas', style: const TextStyle(color: muted, fontSize: 10)),
      if (MediaQuery.sizeOf(context).width > 500) const Text('AES-CBC · PKCS7', style: TextStyle(color: muted, fontSize: 10)),
    ]));
}

String _duration(Duration? d) => d == null ? '…' : d.inMilliseconds < 1000
    ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(2)} s';
String _time(DateTime dt) {
  final d = dt.toLocal();
  String p(int n, int width) => n.toString().padLeft(width, '0');
  return '${p(d.hour, 2)}:${p(d.minute, 2)}:${p(d.second, 2)}.${p(d.millisecond, 3)}';
}
