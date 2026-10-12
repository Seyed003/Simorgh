/// Outcome of one real-delay test.
class LatencyResult {
  const LatencyResult._(this.delay, this.failure, this.testedAt);

  const LatencyResult.success(int delay, DateTime testedAt)
    : this._(delay, null, testedAt);

  const LatencyResult.failure(LatencyFailure failure, DateTime testedAt)
    : this._(null, failure, testedAt);

  /// Round trip in milliseconds, `null` when the test failed.
  final int? delay;
  final LatencyFailure? failure;
  final DateTime testedAt;

  bool get ok => delay != null;

  Map<String, Object?> toJson() => {
    if (delay != null) 'd': delay,
    if (failure != null) 'f': failure!.name,
    't': testedAt.millisecondsSinceEpoch,
  };

  static LatencyResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['t'];
    if (at is! int) return null;
    final testedAt = DateTime.fromMillisecondsSinceEpoch(at);
    final delay = json['d'];
    if (delay is int) return LatencyResult.success(delay, testedAt);
    final failure = LatencyFailure.values.asNameMap()[json['f']];
    return failure == null ? null : LatencyResult.failure(failure, testedAt);
  }
}

enum LatencyFailure {
  /// The server did not answer in time or the handshake failed.
  unreachable,

  /// The core rejected this config (e.g. a malformed key).
  invalidConfig,

  /// The test core could not start at all.
  coreError,
}

/// Which servers are being tested and how far along the run is.
class LatencyState {
  const LatencyState({
    this.results = const {},
    this.testing = const {},
    this.total = 0,
    this.done = 0,
  });

  /// Latest result per profile id.
  final Map<String, LatencyResult> results;

  /// Profile ids still waiting for a result in the current run.
  final Set<String> testing;
  final int total;
  final int done;

  bool get running => testing.isNotEmpty;

  LatencyState copyWith({
    Map<String, LatencyResult>? results,
    Set<String>? testing,
    int? total,
    int? done,
  }) => LatencyState(
    results: results ?? this.results,
    testing: testing ?? this.testing,
    total: total ?? this.total,
    done: done ?? this.done,
  );
}
