import '../../profiles/domain/profile.dart';
import '../domain/latency_result.dart';

/// How many of the fastest servers auto mode hands to the core. The core
/// keeps re-testing all of them and fails over between them.
const autoCandidateLimit = 10;

/// With fewer fresh working servers than this (or than the user has), auto
/// mode re-tests everything before connecting so failover has options.
const autoMinCandidates = 3;

/// Latency results older than this are re-measured before auto mode
/// connects: blocked servers change quickly.
const autoResultMaxAge = Duration(hours: 1);

/// The fastest servers that answered a latency test within [maxAge],
/// fastest first.
List<Profile> pickAutoCandidates(
  List<Profile> profiles,
  Map<String, LatencyResult> results, {
  required DateTime now,
  int limit = autoCandidateLimit,
  Duration maxAge = autoResultMaxAge,
}) {
  final oldest = now.subtract(maxAge);
  final working = [
    for (final p in profiles)
      if (results[p.id] case LatencyResult(:final delay?, :final testedAt)
          when testedAt.isAfter(oldest))
        (profile: p, delay: delay),
  ]..sort((a, b) => a.delay.compareTo(b.delay));
  return [for (final w in working.take(limit)) w.profile];
}

/// The servers auto mode hands to the core when no test confirmed any: the
/// test core can miss servers that work, so every server the core could
/// load is tried, in list order. Servers the core rejected, and those that
/// still need a login, are left out.
List<Profile> pickUnverifiedAutoCandidates(
  List<Profile> profiles,
  Map<String, LatencyResult> results, {
  int limit = autoCandidateLimit,
}) => [
  for (final p in profiles)
    if (!p.config.needsLogin &&
        results[p.id]?.failure != LatencyFailure.invalidConfig)
      p,
].take(limit).toList();
