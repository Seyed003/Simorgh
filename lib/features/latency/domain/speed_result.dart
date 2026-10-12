import 'latency_result.dart';

/// Outcome of one download speed test.
class SpeedResult {
  const SpeedResult._(this.bytesPerSecond, this.failure, this.testedAt);

  const SpeedResult.success(int bytesPerSecond, DateTime testedAt)
    : this._(bytesPerSecond, null, testedAt);

  const SpeedResult.failure(LatencyFailure failure, DateTime testedAt)
    : this._(null, failure, testedAt);

  /// Average download throughput, `null` when the test failed.
  final int? bytesPerSecond;
  final LatencyFailure? failure;
  final DateTime testedAt;

  bool get ok => bytesPerSecond != null;

  Map<String, Object?> toJson() => {
    if (bytesPerSecond != null) 'b': bytesPerSecond,
    if (failure != null) 'f': failure!.name,
    't': testedAt.millisecondsSinceEpoch,
  };

  static SpeedResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['t'];
    if (at is! int) return null;
    final testedAt = DateTime.fromMillisecondsSinceEpoch(at);
    final speed = json['b'];
    if (speed is int) return SpeedResult.success(speed, testedAt);
    final failure = LatencyFailure.values.asNameMap()[json['f']];
    return failure == null ? null : SpeedResult.failure(failure, testedAt);
  }
}

/// Download speed results and the run in progress (servers are tested one
/// at a time so they do not share bandwidth).
class SpeedState {
  const SpeedState({
    this.results = const {},
    this.current,
    this.total = 0,
    this.done = 0,
  });

  /// Latest result per profile id.
  final Map<String, SpeedResult> results;

  /// Profile id being measured right now.
  final String? current;
  final int total;
  final int done;

  bool get running => total > 0 && done < total;

  SpeedState copyWith({
    Map<String, SpeedResult>? results,
    String? Function()? current,
    int? total,
    int? done,
  }) => SpeedState(
    results: results ?? this.results,
    current: current != null ? current() : this.current,
    total: total ?? this.total,
    done: done ?? this.done,
  );
}
