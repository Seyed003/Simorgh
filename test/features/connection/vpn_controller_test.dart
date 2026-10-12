import 'dart:convert';

import 'package:aghelan_ghiamat/core/storage/preferences.dart';
import 'package:aghelan_ghiamat/features/connection/application/vpn_controller.dart';
import 'package:aghelan_ghiamat/features/connection/data/vpn_platform.dart';
import 'package:aghelan_ghiamat/features/connection/domain/vpn_state.dart';
import 'package:aghelan_ghiamat/features/profiles/application/profiles_controller.dart';
import 'package:aghelan_ghiamat/features/profiles/data/profile_store.dart';
import 'package:aghelan_ghiamat/features/settings/application/core_options_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/singbox/fixtures.dart';
import '../../fakes.dart';
import '../../helpers.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeVpnPlatform platform;

  Future<ProviderContainer> create({
    String links = '',
    FakeVpnPlatform? fake,
  }) async {
    platform = fake ?? FakeVpnPlatform();
    final prefs = await mockPreferences();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(MemoryProfileStore()),
        vpnPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    container.listen(vpnControllerProvider, (_, _) {});
    await container.read(profilesProvider.future);
    if (links.isNotEmpty) {
      await container.read(profilesProvider.notifier).importText(links);
    }
    return container;
  }

  test('connect without a profile reports an error', () async {
    final c = await create();
    await c.read(vpnControllerProvider.notifier).connect();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.disconnected);
    expect(state.error!.code, VpnErrorCode.invalidConfig);
    expect(platform.requests, isEmpty);
  });

  test('connect builds a config and goes connected on VpnStarted', () async {
    final c = await create(links: vlessReality);
    final controller = c.read(vpnControllerProvider.notifier);
    final pending = controller.connect();
    await pending;
    expect(c.read(vpnControllerProvider).status, VpnStatus.connecting);
    await _settle();

    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.connected);
    expect(state.connectedSince, isNotNull);
    expect(state.clashApi, isNotNull);

    final request = platform.requests.single;
    expect(request.profileName, 'Reality 🇳🇱');
    final config = jsonDecode(request.configJson) as Map<String, Object?>;
    final api = (config['experimental']! as Map)['clash_api']! as Map;
    expect(api['external_controller'], state.clashApi!.controller);
    expect(api['secret'], state.clashApi!.secret);
  });

  test('toggle disconnects', () async {
    final c = await create(links: trojanBare);
    final controller = c.read(vpnControllerProvider.notifier);
    await controller.toggle();
    await _settle();
    await controller.toggle();
    expect(c.read(vpnControllerProvider).status, VpnStatus.disconnecting);
    await _settle();
    expect(c.read(vpnControllerProvider).status, VpnStatus.disconnected);
    expect(platform.stopCalls, 1);
  });

  test('platform start errors are surfaced', () async {
    final c = await create(
      links: trojanBare,
      fake: FakeVpnPlatform(
        startError: const VpnError(VpnErrorCode.permissionDenied),
      ),
    );
    await c.read(vpnControllerProvider.notifier).connect();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.disconnected);
    expect(state.error!.code, VpnErrorCode.permissionDenied);
  });

  test('core crash moves to disconnected with the error', () async {
    final c = await create(links: trojanBare);
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    platform.emit(const VpnStopped(VpnError(VpnErrorCode.coreExited, 'boom')));
    await _settle();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.disconnected);
    expect(state.error!.message, 'boom');
  });

  test('a dropped connection reconnects once, not in a loop', () async {
    VpnController.reconnectDelay = const Duration(milliseconds: 10);
    addTearDown(
      () => VpnController.reconnectDelay = const Duration(seconds: 2),
    );
    final c = await create(links: trojanBare);
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    platform.emit(const VpnStopped(VpnError(VpnErrorCode.coreExited, 'boom')));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _settle();
    expect(platform.requests, hasLength(2));
    expect(c.read(vpnControllerProvider).status, VpnStatus.connected);

    // Dying again right away is left to the user.
    platform.emit(const VpnStopped(VpnError(VpnErrorCode.coreExited, 'boom')));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _settle();
    expect(platform.requests, hasLength(2));
    expect(c.read(vpnControllerProvider).status, VpnStatus.disconnected);
  });

  test('selecting another profile while connected reconnects to it', () async {
    final c = await create(links: '$trojanBare\n$socks');
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    final socksId = c.read(profilesProvider).value!.profiles.last.id;
    await c.read(profilesProvider.notifier).select(socksId);
    await _settle();
    await _settle();
    expect(platform.stopCalls, 1);
    expect(platform.requests.map((r) => r.profileName), ['bare', 'SOCKS']);
    expect(c.read(vpnControllerProvider).status, VpnStatus.connected);
    expect(c.read(vpnControllerProvider).profileId, socksId);
  });

  test('changing core options while connected restarts the core', () async {
    final c = await create(links: trojanBare);
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    await c
        .read(coreOptionsProvider.notifier)
        .update((o) => o.copyWith(enableIpv6: true));
    await _settle();
    await _settle();
    expect(platform.requests, hasLength(2));
    expect(
      platform.requests.last.configJson,
      contains('fdfe:dcba:9876::1/126'),
    );
  });

  test('reattaches to a service that is already running', () async {
    final c = await create(
      links: trojanBare,
      fake: FakeVpnPlatform(running: true),
    );
    await _settle();
    expect(c.read(vpnControllerProvider).status, VpnStatus.connected);
  });

  test('a start from outside the app picks up the saved session', () async {
    final c = await create(links: trojanBare);
    // The app connected once, which saved the session with the config.
    await c.read(vpnControllerProvider.notifier).connect();
    await _settle();
    final saved = c.read(vpnControllerProvider).clashApi!;
    await c.read(vpnControllerProvider.notifier).disconnect();
    await _settle();
    expect(c.read(vpnControllerProvider).clashApi, isNull);

    // Quick settings tile reconnects; the app only sees the event.
    platform.emit(const VpnStarted());
    await _settle();
    final state = c.read(vpnControllerProvider);
    expect(state.status, VpnStatus.connected);
    expect(state.clashApi!.port, saved.port);
    expect(state.profileId, c.read(profilesProvider).value!.selectedId);
  });
}
