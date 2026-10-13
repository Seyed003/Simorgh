import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../warp/presentation/warp_actions.dart';
import 'import_actions.dart';

Future<void> showAddConfigSheet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final action =
      await showModalBottomSheet<Future<void> Function(ImportActions)>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Option(
                icon: Icons.content_paste_rounded,
                label: l10n.importFromClipboard,
                action: (a) => a.fromClipboard(),
              ),
              if (cameraScanSupported)
                _Option(
                  icon: Icons.qr_code_scanner_rounded,
                  label: l10n.scanQrCode,
                  action: (a) => a.scanQr(),
                ),
              _Option(
                icon: Icons.image_search_rounded,
                label: l10n.importFromImage,
                action: (a) => a.fromImage(),
              ),
              _Option(
                icon: Icons.edit_note_rounded,
                label: l10n.pasteManually,
                action: (a) => a.pasteManually(),
              ),
              _Option(
                icon: Icons.file_open_rounded,
                label: l10n.importFromFile,
                action: (a) => a.fromFile(),
              ),
              _Option(
                icon: Icons.rss_feed_rounded,
                label: l10n.addSubscription,
                action: (a) => a.addSubscription(),
              ),
              _Option(
                icon: Icons.vpn_lock_rounded,
                label: l10n.ciscoAdd,
                action: (a) => a.addCisco(),
              ),
              _Option(
                icon: Icons.cloud_rounded,
                label: l10n.warpAdd,
                action: (a) => WarpActions(a.context, a.ref).add(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
  if (action != null && context.mounted) {
    await action(ImportActions(context, ref));
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.action,
  });

  final IconData icon;
  final String label;
  final Future<void> Function(ImportActions) action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, action),
    );
  }
}
