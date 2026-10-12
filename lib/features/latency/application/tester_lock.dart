import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The platform runs one test core at a time, so latency and speed runs
/// take turns instead of stopping each other's core.
final testerLockProvider = Provider<TesterLock>((ref) => TesterLock());

class TesterLock {
  Future<void> _tail = Future.value();

  /// Runs [body] after every previously queued body has finished.
  Future<T> run<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
