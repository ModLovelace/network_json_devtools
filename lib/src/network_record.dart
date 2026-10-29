import 'dart:convert';
import 'package:vm_service/vm_service.dart';

class NetworkRecord {
  NetworkRecord(this.profile);
  HttpProfileRequest profile;
  HttpProfileRequest? detail;
  String? detailError;
  String get key => '${profile.isolateId}/${profile.id}';
  String get method => profile.method;
  String get url => profile.uri.toString();
  int? get status => profile.response?.statusCode;
  bool get complete => profile.isResponseComplete ||
      profile.response?.hasError == true || profile.request?.error != null;
  String get requestText => _text(detail?.requestBody);
  String get responseText => _text(detail?.responseBody);
  Duration? get duration => (profile.response?.endTime ?? profile.endTime)
      ?.difference(profile.startTime);
  String? get error => profile.response?.error ?? profile.request?.error;
  Map<String, dynamic> get requestHeaders {
    final request = detail?.request ?? profile.request;
    return request?.hasError == true ? {} : request?.headers ?? {};
  }
  Map<String, dynamic> get responseHeaders => detail?.response?.headers ?? profile.response?.headers ?? {};
  String get type {
    String? contentType;
    for (final headers in [responseHeaders, requestHeaders]) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == 'content-type') {
          contentType = entry.value is List ? (entry.value as List).join(';') : entry.value.toString();
          break;
        }
      }
      if (contentType != null) break;
    }
    if (contentType == null) return '—';
    if (contentType.contains('json')) return 'json';
    return contentType.split(';').first.split('/').last;
  }

  bool matches(String search, String filter) {
    if (search.isNotEmpty && !'$method $url ${status ?? ''}'
        .toLowerCase().contains(search.toLowerCase())) return false;
    for (final token in filter.trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final parts = token.split(':');
      final type = parts.first.toLowerCase();
      final value = parts.skip(1).join(':').toLowerCase();
      if (parts.length > 1 && ['m', 'method'].contains(type)) {
        if (method.toLowerCase() != value) return false;
      } else if (parts.length > 1 && ['s', 'status'].contains(type)) {
        if ((status?.toString() ?? 'pending') != value) return false;
      } else if (parts.length > 1 && ['t', 'type'].contains(type)) {
        if (value != this.type.toLowerCase()) return false;
      } else if (!url.toLowerCase().contains(token.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}

String _text(List<int>? bytes) => bytes == null
    ? '' : utf8.decode(bytes, allowMalformed: true);
