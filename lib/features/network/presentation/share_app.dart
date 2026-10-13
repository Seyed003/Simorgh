import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_bridge.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_widgets.dart';

/// Passes the app itself to someone else without the internet: the APK
/// over Bluetooth or a messenger on Android, the app folder on Windows.
Future<void> shareTheApp(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final shared = await ref
      .read(systemBridgeProvider)
      .shareApp(title: l10n.shareAppTitle);
  if (!shared && context.mounted) context.showSnack(l10n.shareAppFailed);
}

class ShareAppTile extends ConsumerWidget {
  const ShareAppTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListTile(
      leading: const TileIcon(Icons.ios_share_rounded, TileIcon.green),
      title: Text(l10n.shareApp),
      subtitle: Text(
        Platform.isWindows ? l10n.shareAppHintWindows : l10n.shareAppHint,
      ),
      onTap: () => shareTheApp(context, ref),
    );
  }
}
