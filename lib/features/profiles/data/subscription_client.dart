import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_info.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final subscriptionClientProvider = Provider<SubscriptionClient>(
  (ref) => SubscriptionClient(ref.watch(httpClientProvider)),
);

class SubscriptionResponse {
  const SubscriptionResponse(this.body, this.headers);

  final String body;
  final Map<String, String> headers;
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads subscription content.
///
/// The User-Agent deliberately avoids names like `sing-box`, `clash` or
/// `v2rayNG` that panels (Marzban, Hiddify, 3x-ui) map to client specific
/// formats, so the server returns the universal base64 link list.
class SubscriptionClient {
  SubscriptionClient(this._client);

  final http.Client _client;

  static const userAgent = 'AghelanGhiamat/${AppInfo.version}';
  static const timeout = Duration(seconds: 20);

  /// Real subscriptions are a few hundred KB at most; anything far bigger
  /// is a broken or hostile server trying to run the phone out of memory.
  static const maxBytes = 8 * 1024 * 1024;

  Future<SubscriptionResponse> fetch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const SubscriptionException('invalid URL');
    }
    final request = http.Request('GET', uri)
      ..headers.addAll({'User-Agent': userAgent, 'Accept': '*/*'});
    final List<int> bytes;
    final http.StreamedResponse response;
    try {
      (response, bytes) = await _download(request).timeout(timeout);
    } on SubscriptionException {
      rethrow;
    } on Exception catch (e) {
      throw SubscriptionException(e.toString());
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    return SubscriptionResponse(body, response.headers);
  }

  Future<(http.StreamedResponse, List<int>)> _download(
    http.Request request,
  ) async {
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubscriptionException('HTTP ${response.statusCode}');
    }
    if ((response.contentLength ?? 0) > maxBytes) {
      throw const SubscriptionException('response too large');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        throw const SubscriptionException('response too large');
      }
    }
    return (response, bytes);
  }
}
