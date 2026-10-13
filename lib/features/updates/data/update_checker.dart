import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_info.dart';
import '../../profiles/data/subscription_client.dart';

/// A published version of the app.
class AppRelease {
  const AppRelease({required this.version, required this.url});

  /// Without the leading `v`, e.g. `0.3.0`.
  final String version;

  /// Release page with the downloads.
  final String url;
}

/// Reads the latest GitHub release. Returns `null` when there is none or it
/// cannot be reached (a private repository looks like "none").
class UpdateChecker {
  const UpdateChecker(this._client, {this.api = AppInfo.latestReleaseApi});

  final http.Client _client;
  final String api;

  Future<AppRelease?> latest() async {
    final response = await _client
        .get(
          Uri.parse(api),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map || json['draft'] == true || json['prerelease'] == true) {
      return null;
    }
    final tag = json['tag_name'];
    if (tag is! String || tag.isEmpty) return null;
    return AppRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      url: json['html_url'] as String? ?? AppInfo.releasesPage,
    );
  }
}

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => UpdateChecker(ref.watch(httpClientProvider)),
);

/// Compares dotted numeric versions (`0.10.1` > `0.9.3`); anything after a
/// `-` or `+` is ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp('[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
