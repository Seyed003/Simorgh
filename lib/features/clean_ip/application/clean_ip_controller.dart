import 'dart:async';

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
  });

  final bool running;
  final int tested;
  final int total;

  /// Working addresses, fastest first.
  final List<CleanIpHit> hits;

  CleanIpState copyWith({
    bool? running,
    int? tested,
    int? total,
    List<CleanIpHit>? hits,
  }) => CleanIpState(
    running: running ?? this.running,
    tested: tested ?? this.tested,
    total: total ?? this.total,
    hits: hits ?? this.hits,
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

  void start(String host) {
    if (state.running) return;
    final scanner = ref.read(cleanIpScannerFactoryProvider)();
    state = CleanIpState(running: true, total: scanner.sampleSize);
    _run = scanner
        .scan(host)
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
