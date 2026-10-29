import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_json_devtools/network_json_devtools.dart';
import 'package:vm_service/vm_service.dart';

class CaptureController extends ChangeNotifier {
  CaptureController(this.serviceProvider);
  final VmService? Function() serviceProvider;
  final records = <String, NetworkRecord>{};
  final _enabled = <String>{};
  final _updatedSince = <String, DateTime>{};
  final _loading = <String>{};
  VmService? _service;
  Timer? _timer;
  bool _disposed = false;
  bool _busy = false;
  int _generation = 0;
  DateTime? _clearedBefore;
  bool recording = true;
  bool connected = false;
  String? message;
  String? selectedKey;
  int evicted = 0;
  NetworkRecord? get selected => records[selectedKey];
  bool get loadingDetail => _loading.contains(selectedKey);

  void start() {
    unawaited(poll());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(poll()));
  }

  void toggleRecording() {
    recording = !recording;
    _generation++;
    // Resume from now instead of importing requests issued while paused.
    if (recording) {
      final now = DateTime.now();
      for (final id in _enabled) { _updatedSince[id] = now; }
    }
    _notify();
    if (recording) unawaited(poll());
  }

  void clear() {
    // Do not call clearHttpProfile: its buffer is shared with Network.
    _generation++;
    _clearedBefore = DateTime.now();
    records.clear();
    selectedKey = null;
    evicted = 0;
    _notify();
  }

  void select(NetworkRecord record) {
    selectedKey = record.key;
    _notify();
    unawaited(loadDetail(record));
  }

  Future<void> poll() async {
    if (_disposed || _busy) return;
    final current = serviceProvider();
    if (!identical(current, _service)) {
      _generation++;
      _service = current;
      _enabled.clear();
      _updatedSince.clear();
      _loading.clear();
      records.clear();
      selectedKey = null;
      _clearedBefore = null;
      evicted = 0;
    }
    connected = current != null;
    if (current == null) {
      message = 'Conecta DevTools a una app Dart o Flutter en debug.';
      _notify();
      return;
    }
    if (!recording) { _notify(); return; }
    _busy = true;
    final generation = _generation;
    bool stale() => _disposed || generation != _generation;
    try {
      final vm = await current.getVM().timeout(const Duration(seconds: 5));
      if (stale()) return;
      var supported = 0;
      var failures = 0;
      for (final isolate in vm.isolates ?? <IsolateRef>[]) {
        final id = isolate.id;
        if (id == null) continue;
        try {
          if (!_enabled.contains(id)) {
            if (!await current.isHttpProfilingAvailable(id)
                .timeout(const Duration(seconds: 3))) {
              continue;
            }
            await current.httpEnableTimelineLogging(id, true)
                .timeout(const Duration(seconds: 3));
            if (stale()) return;
            _enabled.add(id);
          }
          supported++;
          final profile = await current.getHttpProfile(id,
              updatedSince: _updatedSince[id]).timeout(const Duration(seconds: 5));
          if (stale()) return;
          _updatedSince[id] = profile.timestamp;
          for (final ref in profile.requests) {
            if (_clearedBefore != null && !ref.startTime.isAfter(_clearedBefore!)) continue;
            final key = '${ref.isolateId}/${ref.id}';
            final record = records[key];
            if (record == null) {
              records[key] = NetworkRecord(ref);
            } else {
              if (!record.complete) record.detail = null;
              record.profile = ref;
            }
          }
        } catch (_) {
          // Isolates can disappear during hot restart. Retry on the next tick.
          failures++;
          _enabled.remove(id);
          _updatedSince.remove(id);
        }
      }
      if (stale()) return;
      while (records.length > 500) {
        final oldest = records.keys.first;
        records.remove(oldest);
        if (selectedKey == oldest) selectedKey = null;
        evicted++;
      }
      message = failures > 0
          ? 'No se pudo consultar un isolate; reintentando la conexión.'
          : supported == 0
              ? 'Sin perfil HTTP disponible. Usa una app móvil/desktop en debug; Flutter Web requiere el inspector del navegador.'
              : null;
      _notify();
      if (selected != null && selected!.detail == null) {
        unawaited(loadDetail(selected!));
      }
    } catch (_) {
      if (!stale()) {
        message = 'No se pudo leer el perfil HTTP. Comprueba la conexión y reanuda la app si está pausada.';
        _notify();
      }
    } finally { _busy = false; }
  }

  Future<void> loadDetail(NetworkRecord record) async {
    final current = _service;
    if (current == null || _loading.contains(record.key) || record.detail != null) return;
    final generation = _generation;
    _loading.add(record.key);
    _notify();
    try {
      final detail = await current.getHttpProfileRequest(
          record.profile.isolateId, record.profile.id).timeout(const Duration(seconds: 8));
      if (_disposed || generation != _generation) return;
      record.detail = detail;
      record.detailError = null;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        record.detailError = 'No se pudo cargar el cuerpo. Selecciona de nuevo la petición para reintentar.';
      }
    } finally {
      _loading.remove(record.key);
      _notify();
    }
  }

  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    // The VM service belongs to DevTools and must remain open.
    super.dispose();
  }
}
