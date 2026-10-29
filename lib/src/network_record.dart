import 'dart:convert';
import 'package:vm_service/vm_service.dart';

/// An HTTP profiling summary with optional lazily loaded body details.
class NetworkRecord {
  /// Creates a row from an HTTP profiling summary.
  NetworkRecord(this.profile);

  /// The latest summary returned by the Dart VM's HTTP profiler.
  HttpProfileRequest profile;

  /// Full request details loaded when the row is selected, if available.
  HttpProfileRequest? detail;

  /// An error loading [detail], separate from an HTTP transport error.
  String? detailError;

  /// Identity scoped by isolate so equal request IDs do not collide.
  String get key => '${profile.isolateId}/${profile.id}';

  /// The HTTP method reported by the profiler.
  String get method => profile.method;

  /// The complete request URL.
  String get url => profile.uri.toString();

  /// The HTTP status code, or `null` while no response is available.
  int? get status => profile.response?.statusCode;

  /// Whether the response finished or a transport error was recorded.
  bool get complete =>
      profile.isResponseComplete ||
      profile.response?.hasError == true ||
      profile.request?.error != null;

  /// The request body as UTF-8, or an empty string before loading details.
  String get requestText => _text(detail?.requestBody);

  /// The response body as UTF-8, or an empty string before loading details.
  String get responseText => _text(detail?.responseBody);

  /// Time from request start to completion, or `null` while pending.
  Duration? get duration => (profile.response?.endTime ?? profile.endTime)
      ?.difference(profile.startTime);

  /// A transport error reported for this request or response, if any.
  String? get error => profile.response?.error ?? profile.request?.error;

  /// Request headers, preferring loaded details and tolerating failed requests.
  Map<String, dynamic> get requestHeaders {
    final request = detail?.request ?? profile.request;
    return request?.hasError == true ? {} : request?.headers ?? {};
  }

  /// Response headers, preferring loaded details when available.
  Map<String, dynamic> get responseHeaders =>
      detail?.response?.headers ?? profile.response?.headers ?? {};

  /// A short MIME subtype such as `json`, or an em dash if unknown.
  String get type {
    String? contentType;
    for (final headers in [responseHeaders, requestHeaders]) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == 'content-type') {
          contentType = entry.value is List
              ? (entry.value as List).join(';')
              : entry.value.toString();
          break;
        }
      }
      if (contentType != null) break;
    }
    if (contentType == null) return '—';
    if (contentType.contains('json')) return 'json';
    return contentType.split(';').first.split('/').last;
  }

  /// Matches search text and whitespace-separated filters, case-insensitively.
  ///
  /// Search examines method, URL, and status. Filters accept `m:post`, `s:200`,
  /// and `t:json` (or their full names); other tokens match the URL. All tokens
  /// must match. Pending requests can be matched with `s:pending`.
  bool matches(String search, String filter) {
    if (search.isNotEmpty &&
        !'$method $url ${status ?? ''}'.toLowerCase().contains(
          search.toLowerCase(),
        )) {
      return false;
    }
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

String _text(List<int>? bytes) =>
    bytes == null ? '' : utf8.decode(bytes, allowMalformed: true);
