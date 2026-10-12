import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';
import '../application/profiles_controller.dart';

/// Refreshes stale subscriptions when the app starts and whenever it comes
/// back to the foreground, per the user's update interval. No background
/// timers: nothing runs while the app is closed.
class SubscriptionAutoUpdate extends ConsumerStatefulWidget {
  const SubscriptionAutoUpdate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SubscriptionAutoUpdate> createState() =>
      _SubscriptionAutoUpdateState();
}

class _SubscriptionAutoUpdateState
    extends ConsumerState<SubscriptionAutoUpdate> {
  /// A failed subscription is not retried sooner than this.
  static const _retryAfter = Duration(minutes: 30);

  late final AppLifecycleListener _lifecycle;
  final _lastAttempt = <String, DateTime>{};
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final hours = ref.read(settingsProvider).subscriptionUpdateHours;
    if (hours <= 0 || _running || !mounted) return;
    _running = true;
    try {
      final now = DateTime.now();
      final tried = await ref
          .read(profilesProvider.notifier)
          .updateDueSubscriptions(
            Duration(hours: hours),
            skip: {
              for (final MapEntry(:key, :value) in _lastAttempt.entries)
                if (now.difference(value) < _retryAfter) key,
            },
          );
      for (final id in tried) {
        _lastAttempt[id] = now;
      }
    } on Object {
      // Profiles failed to load; nothing to refresh.
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
