import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/generated/app_localizations.dart';
import '../connection/application/vpn_controller.dart';
import '../connection/domain/vpn_state.dart';
import '../profiles/application/profiles_controller.dart';
import '../settings/application/settings_controller.dart';

bool get isDesktop => Platform.isWindows;

/// Prepares the native window before the first frame (Windows only).
Future<void> initDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(400, 600),
    center: true,
    title: 'Aghelan Ghiamat',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

/// Tray icon with connect/disconnect, and "close to tray" behaviour.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    if (!isDesktop) return;
    trayManager.addListener(this);
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    unawaited(_updateTray());
  }

  @override
  void dispose() {
    if (isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(settingsProvider).language.locale);

  Future<void> _updateTray() async {
    final l10n = _l10n;
    final state = ref.read(vpnControllerProvider);
    final connected = state.isConnected;
    final status = switch (state.status) {
      VpnStatus.disconnected => l10n.statusDisconnected,
      VpnStatus.connecting => l10n.statusConnecting,
      VpnStatus.connected => l10n.statusConnected,
      VpnStatus.disconnecting => l10n.statusDisconnecting,
    };
    final profiles = ref.read(profilesProvider).value;
    final profile = profiles != null && profiles.isAuto
        ? l10n.autoSelect
        : profiles?.selected?.name;
    await trayManager.setIcon(
      connected
          ? 'assets/tray/tray_connected.ico'
          : 'assets/tray/tray_disconnected.ico',
    );
    await trayManager.setToolTip([l10n.appTitle, status, ?profile].join('\n'));
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: l10n.trayShow),
          MenuItem(
            key: 'toggle',
            label: connected ? l10n.disconnect : l10n.connect,
            disabled: state.isBusy,
          ),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: l10n.trayQuit),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await ref.read(vpnControllerProvider.notifier).disconnect();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_showWindow());
      case 'toggle':
        unawaited(ref.read(vpnControllerProvider.notifier).toggle());
      case 'quit':
        unawaited(_quit());
    }
  }

  @override
  void onWindowClose() => unawaited(windowManager.hide());

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      ref.listen(vpnControllerProvider, (_, _) => unawaited(_updateTray()));
      ref.listen(settingsProvider, (_, _) => unawaited(_updateTray()));
      ref.listen(
        profilesProvider.select((s) => s.value?.selected?.name),
        (_, _) => unawaited(_updateTray()),
      );
      ref.listen(
        profilesProvider.select((s) => s.value?.isAuto),
        (_, _) => unawaited(_updateTray()),
      );
    }
    return widget.child;
  }
}
