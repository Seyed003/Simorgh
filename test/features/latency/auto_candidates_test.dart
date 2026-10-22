import 'package:aghelan_ghiamat/core/singbox/link_parser.dart';
import 'package:aghelan_ghiamat/core/singbox/protocols/openvpn.dart';
import 'package:aghelan_ghiamat/features/latency/application/auto_candidates.dart';
import 'package:aghelan_ghiamat/features/latency/domain/latency_result.dart';
import 'package:aghelan_ghiamat/features/profiles/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../core/singbox/openvpn_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 12, 12);
  final config = LinkParser.parse(trojanBare);
  List<Profile> profiles(int n) => [
    for (var i = 0; i < n; i++)
      Profile(id: 'p$i', config: config, createdAt: now),
  ];

  test('fastest working servers first, failures and stale results out', () {
    final picked = pickAutoCandidates(profiles(5), {
      'p0': LatencyResult.success(400, now),
      'p1': LatencyResult.failure(LatencyFailure.unreachable, now),
      'p2': LatencyResult.success(90, now.subtract(const Duration(minutes: 5))),
      'p3': LatencyResult.success(10, now.subtract(const Duration(hours: 2))),
      // p4 never tested
    }, now: now);
    expect(picked.map((p) => p.id), ['p2', 'p0']);
  });

  test('keeps at most limit candidates', () {
    final picked = pickAutoCandidates(profiles(20), {
      for (var i = 0; i < 20; i++) 'p$i': LatencyResult.success(1000 - i, now),
    }, now: now);
    expect(picked, hasLength(autoCandidateLimit));
    expect(picked.first.id, 'p19');
  });

  test('unconfirmed candidates: list order, without rejected or login', () {
    final needsLogin = Profile(
      id: 'login',
      config: parseOpenVpn(ovpnProfile),
      createdAt: now,
    );
    final picked = pickUnverifiedAutoCandidates(
      [...profiles(4), needsLogin],
      {
        'p0': LatencyResult.failure(LatencyFailure.unreachable, now),
        'p1': LatencyResult.failure(LatencyFailure.invalidConfig, now),
        'p2': LatencyResult.failure(LatencyFailure.coreError, now),
        // p3 never tested
      },
    );
    expect(picked.map((p) => p.id), ['p0', 'p2', 'p3']);
    expect(
      pickUnverifiedAutoCandidates(profiles(20), const {}),
      hasLength(autoCandidateLimit),
    );
  });
}
