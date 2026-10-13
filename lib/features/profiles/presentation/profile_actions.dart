import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../clean_ip/presentation/clean_ip_page.dart';
import '../../latency/application/speed_controller.dart';
import '../../warp/data/warp_client.dart';
import '../../warp/presentation/warp_actions.dart';
import '../application/profiles_controller.dart';
import '../domain/profile.dart';
import 'import_actions.dart';

enum _ProfileAction {
  login,
  speedTest,
  cleanIp,
  warpEndpoint,
  showQr,
  copyLink,
  copyJson,
  rename,
  delete,
}

Future<void> showProfileActions(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final l10n = context.l10n;
  final hasLink = profile.config.link != null;
  // OpenVPN profiles carry their certificates: far too long for a QR code.
  final qrData = profile.config.link ?? profile.config.toPrettyJson();
  final fitsQr = qrData.length <= 2000;
  final action = await showModalBottomSheet<_ProfileAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              profile.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.theme.textTheme.titleMedium,
            ),
          ),
          if (profile.config.protocol.hasLogin)
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: Text(l10n.loginTitle),
              onTap: () => Navigator.pop(context, _ProfileAction.login),
            ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text(l10n.speedTest),
            onTap: () => Navigator.pop(context, _ProfileAction.speedTest),
          ),
          if (profile.config.isCdnCandidate)
            ListTile(
              leading: const Icon(Icons.radar_rounded),
              title: Text(l10n.cleanIpScan),
              onTap: () => Navigator.pop(context, _ProfileAction.cleanIp),
            ),
          if (isWarp(profile.config))
            ListTile(
              leading: const Icon(Icons.cloud_sync_rounded),
              title: Text(l10n.warpScan),
              onTap: () => Navigator.pop(context, _ProfileAction.warpEndpoint),
            ),
          if (fitsQr)
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text(l10n.showQrCode),
              onTap: () => Navigator.pop(context, _ProfileAction.showQr),
            ),
          if (hasLink)
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l10n.copyLink),
              onTap: () => Navigator.pop(context, _ProfileAction.copyLink),
            ),
          ListTile(
            leading: const Icon(Icons.data_object_rounded),
            title: Text(l10n.copyJson),
            onTap: () => Navigator.pop(context, _ProfileAction.copyJson),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: Text(l10n.rename),
            onTap: () => Navigator.pop(context, _ProfileAction.rename),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: context.colors.error,
            ),
            title: Text(
              l10n.delete,
              style: TextStyle(color: context.colors.error),
            ),
            onTap: () => Navigator.pop(context, _ProfileAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  final controller = ref.read(profilesProvider.notifier);
  switch (action) {
    case _ProfileAction.login:
      await ImportActions(context, ref).login(profile);
    case _ProfileAction.speedTest:
      await ref.read(speedProvider.notifier).test([profile.id]);
    case _ProfileAction.cleanIp:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CleanIpPage(profile: profile)),
      );
    case _ProfileAction.warpEndpoint:
      await WarpActions(context, ref).findEndpoint(profile);
    case _ProfileAction.showQr:
      await _showQr(context, qrData);
    case _ProfileAction.copyLink:
      await Clipboard.setData(ClipboardData(text: profile.config.link!));
      if (context.mounted) context.showSnack(l10n.copied);
    case _ProfileAction.copyJson:
      await Clipboard.setData(
        ClipboardData(text: profile.config.toPrettyJson()),
      );
      if (context.mounted) context.showSnack(l10n.copied);
    case _ProfileAction.rename:
      final name = await textInputDialog(
        context,
        title: l10n.rename,
        label: l10n.name,
        initialValue: profile.name,
        validator: (v) => v.trim().isEmpty ? l10n.invalidValue : null,
      );
      if (name != null) await controller.rename(profile.id, name.trim());
    case _ProfileAction.delete:
      final ok = await confirmDialog(
        context,
        title: l10n.deleteConfirmTitle,
        message: l10n.deleteConfigConfirm(profile.name),
        confirmLabel: l10n.delete,
        destructive: true,
      );
      if (ok) await controller.deleteProfile(profile.id);
  }
}

Future<void> _showQr(BuildContext context, String data) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 300,
        height: 300,
        child: QrImageView(
          data: data,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(12),
          errorCorrectionLevel: QrErrorCorrectLevel.L,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}
