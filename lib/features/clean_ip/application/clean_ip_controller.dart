import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clean_ip_scanner.dart';

/// Builds the scanner for a run; overridable in tests.
final cleanIpScannerFactoryProvider = Provider<CleanIpScanner Function()>(
  (ref) => CleanIpScanner.new,
);

final cleanIpProvider =
    NotifierProvider.autoDispose<CleanIpController, CleanIpState>(
      CleanIpController.new,
    );

class CleanIpState {
  const CleanIpState({
    this.running = false,
    this.tested = 0,
    this.total = 0,
    this.hits = const [],
    this.provider = CdnProvider.cloudflare,
  });

  final bool running;

  /// The CDN being (or last) scanned.
  final CdnProvider provider;
  final int tested;
  final int total;

  /// Working addresses, fastest first.
  final List<CleanIpHit> hits;

  CleanIpState copyWith({
    bool? running,
    int? tested,
    int? total,
    List<CleanIpHit>? hits,
    CdnProvider? provider,
  }) => CleanIpState(
    running: running ?? this.running,
    tested: tested ?? this.tested,
    total: total ?? this.total,
    hits: hits ?? this.hits,
    provider: provider ?? this.provider,
  );
}

class CleanIpController extends Notifier<CleanIpState> {
  /// How many of the fastest addresses are kept.
  static const keep = 30;

  StreamSubscription<CleanIpUpdate>? _run;

  @override
  CleanIpState build() {
    ref.onDispose(() => _run?.cancel());
    return const CleanIpState();
  }

  /// Chooses the CDN for the next scan.
  void choose(CdnProvider provider) {
    if (state.running) return;
    state = CleanIpState(provider: provider);
  }

  void start(String host) {
    if (state.running) return;
    final scanner = ref.read(cleanIpScannerFactoryProvider)();
    final provider = state.provider;
    state = CleanIpState(
      running: true,
      total: CleanIpScanner.sample(
        scanner.sampleSize,
        Random(0),
        ranges: provider.ranges,
      ).length,
      provider: provider,
    );
    _run = scanner
        .scan(host, provider: provider)
        .listen(
          (update) {
            final hit = update.hit;
            state = state.copyWith(
              tested: state.tested + 1,
              hits: hit == null
                  ? null
                  : ([...state.hits, hit]
                          ..sort((a, b) => a.latencyMs.compareTo(b.latencyMs)))
                        .take(keep)
                        .toList(),
            );
          },
          onDone: _finish,
          onError: (Object _) => _finish(),
          cancelOnError: true,
        );
  }

  Future<void> stop() async {
    final run = _run;
    _finish();
    await run?.cancel();
  }

  void _finish() {
    _run = null;
    state = state.copyWith(running: false);
  }
}
