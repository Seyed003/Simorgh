import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../settings/application/core_options_controller.dart';
import '../../settings/domain/dns_presets.dart';
import '../data/reach_probe.dart';

final reachProbeProvider = Provider<ReachProbe>((ref) => const ReachProbe());

final internetReachProvider =
    NotifierProvider<InternetReachController, InternetReachState>(
      InternetReachController.new,
    );

class InternetReachState {
  const InternetReachState({this.reach, this.checking = false, this.checkedAt});

  /// `null` until the first check.
  final InternetReach? reach;
  final bool checking;
  final DateTime? checkedAt;

  bool get domesticOnly => reach == InternetReach.domesticOnly;
}

/// Watches for the national internet. Checks run while the VPN is off
/// (the callers make sure), since through a working tunnel everything
/// answers.
class InternetReachController extends Notifier<InternetReachState> {
  @override
  InternetReachState build() => const InternetReachState();

  Future<void> check() async {
    if (state.checking) return;
    state = InternetReachState(
      reach: state.reach,
      checking: true,
      checkedAt: state.checkedAt,
    );
    final reach = await ref.read(reachProbeProvider).run();
    if (!ref.mounted) return;
    state = InternetReachState(reach: reach, checkedAt: DateTime.now());
  }

  /// Checks again unless the last check is younger than [maxAge].
  Future<void> refresh({Duration maxAge = const Duration(minutes: 3)}) async {
    final at = state.checkedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) return;
    await check();
  }
}

/// The options the core runs with: the user's, except that on the national
/// internet a foreign direct DNS (cut off with everything else abroad)
/// gives way to the system's own resolver, so server names still resolve.
final effectiveCoreOptionsProvider = Provider<CoreOptions>((ref) {
  final options = ref.watch(coreOptionsProvider);
  final domesticOnly = ref.watch(
    internetReachProvider.select((s) => s.domesticOnly),
  );
  return domesticOnly ? withDomesticDns(options) : options;
});

CoreOptions withDomesticDns(CoreOptions options) =>
    isDomesticDns(options.directDns)
    ? options
    : options.copyWith(directDns: 'local');
