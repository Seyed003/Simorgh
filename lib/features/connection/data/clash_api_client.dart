import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/singbox/builder/core_options.dart';

/// Minimal client for the Clash-compatible API exposed by sing-box.
class ClashApiClient {
  ClashApiClient(this.options, {http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final ClashApiOptions options;
  final http.Client Function() _clientFactory;

  Uri _uri(String path) => Uri.parse('http://${options.controller}$path');

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${options.secret}',
  };

  /// Whether the API answers, used to detect that the core is up.
  Future<bool> ping() async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(_uri('/version'), headers: _headers)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } on Exception {
      return false;
    } finally {
      client.close();
    }
  }

  /// Per-second `(up, down)` byte counts streamed by `GET /traffic`.
  Stream<({int up, int down})> traffic() {
    late final StreamController<({int up, int down})> controller;
    http.Client? client;
    StreamSubscription<String>? subscription;

    Future<void> open() async {
      client = _clientFactory();
      try {
        final request = http.Request('GET', _uri('/traffic'))
          ..headers.addAll(_headers);
        final response = await client!.send(request);
        if (response.statusCode != 200) {
          controller.addError(
            StateError('traffic: HTTP ${response.statusCode}'),
          );
          await controller.close();
          return;
        }
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                final sample = parseTrafficLine(line);
                if (sample != null) controller.add(sample);
              },
              onError: controller.addError,
              onDone: controller.close,
            );
      } on Exception catch (e) {
        controller.addError(e);
        await controller.close();
      }
    }

    controller = StreamController(
      onListen: open,
      onCancel: () async {
        await subscription?.cancel();
        client?.close();
      },
    );
    return controller.stream;
  }

  static ({int up, int down})? parseTrafficLine(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final json = jsonDecode(line);
      if (json is! Map) return null;
      final up = json['up'];
      final down = json['down'];
      return (
        up: up is num ? up.toInt() : 0,
        down: down is num ? down.toInt() : 0,
      );
    } on FormatException {
      return null;
    }
  }
}
