import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.system,
  });

  final String packageName;
  final String label;
  final bool system;
}

/// Apps installed on the device (Android), for per-app split tunneling.
abstract class InstalledAppsSource {
  Future<List<InstalledApp>> list();

  /// PNG bytes of the app's icon, `null` when unavailable.
  Future<Uint8List?> icon(String packageName);
}

class ChannelInstalledApps implements InstalledAppsSource {
  const ChannelInstalledApps();

  static const _channel = MethodChannel('com.aghelan.ghiamat/apps');

  @override
  Future<List<InstalledApp>> list() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list');
    return [
      for (final app in raw ?? const <Map<Object?, Object?>>[])
        InstalledApp(
          packageName: app['package']! as String,
          label: app['label'] as String? ?? app['package']! as String,
          system: app['system'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<Uint8List?> icon(String packageName) => _channel
      .invokeMethod<Uint8List>('icon', {'package': packageName, 'size': 96});
}

final installedAppsSourceProvider = Provider<InstalledAppsSource>(
  (ref) => const ChannelInstalledApps(),
);

/// Installed apps sorted by name; reloaded each time the picker opens.
final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>((
  ref,
) async {
  final apps = await ref.watch(installedAppsSourceProvider).list();
  return [...apps]
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
});

/// Cached icon per package.
final appIconProvider = FutureProvider.family<Uint8List?, String>(
  (ref, packageName) =>
      ref.watch(installedAppsSourceProvider).icon(packageName),
);
