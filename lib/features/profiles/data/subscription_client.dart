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

  Future<SubscriptionResponse> fetch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw const SubscriptionException('invalid URL');
    }
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': '*/*'})
          .timeout(timeout);
    } on Exception catch (e) {
      throw SubscriptionException(e.toString());
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubscriptionException('HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    return SubscriptionResponse(body, response.headers);
  }
}
