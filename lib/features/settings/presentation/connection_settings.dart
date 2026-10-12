import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/builder/dns_server.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/utils/formatters.dart';
import '../../connection/application/vpn_controller.dart';
import '../application/core_options_controller.dart';
import '../domain/dns_presets.dart';
import 'split_tunnel_page.dart';

const _fingerprints = [
  'chrome',
  'firefox',
  'safari',
  'edge',
  'ios',
  'android',
  'random',
  'randomized',
];

/// Core tunables. Changes restart a running connection automatically.
class ConnectionSettingsSection extends ConsumerWidget {
  const ConnectionSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final options = ref.watch(coreOptionsProvider);
    final controller = ref.read(coreOptionsProvider.notifier);

    String? validateDns(String value) {
      try {
        parseDnsServer(value, tag: 'check');
        return null;
      } on LinkParseException {
        return l10n.invalidValue;
      } on FormatException {
        return l10n.invalidValue;
      }
    }

    Future<void> editDns({required bool remote}) async {
      final current = remote ? options.remoteDns : options.directDns;
      final presets = remote ? remoteDnsPresets : directDnsPresets;
      const custom = '';
      final picked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    remote ? l10n.remoteDns : l10n.directDns,
                    style: context.theme.textTheme.titleMedium,
                  ),
                ),
                for (final preset in presets)
                  ListTile(
                    title: Text(
                      preset.address == 'local'
                          ? l10n.dnsSystem
                          : preset.blocksAds
                          ? '${preset.name} · ${l10n.dnsBlocksAds}'
                          : preset.name,
                    ),
                    subtitle: Text(
                      preset.address,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                    ),
                    trailing: preset.address == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: context.colors.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, preset.address),
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.dnsCustom),
                  onTap: () => Navigator.pop(context, custom),
                ),
              ],
            ),
          ),
        ),
      );
      if (picked == null || !context.mounted) return;
      final value = picked == custom
          ? await textInputDialog(
              context,
              title: remote ? l10n.remoteDns : l10n.directDns,
              initialValue: current,
              hint: l10n.dnsAddressHint,
              ltr: true,
              keyboardType: TextInputType.url,
              validator: validateDns,
            )
          : picked;
      if (value == null) return;
      await controller.update(
        (o) => remote
            ? o.copyWith(remoteDns: value.trim())
            : o.copyWith(directDns: value.trim()),
      );
    }

    Future<void> editPort() async {
      final value = await textInputDialog(
        context,
        title: l10n.mixedPort,
        initialValue: options.mixedPort?.toString() ?? '',
        hint: l10n.portHint,
        ltr: true,
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v.trim().isEmpty) return null;
          final port = int.tryParse(v.trim());
          return port == null || port < 1024 || port > 65535
              ? l10n.invalidValue
              : null;
        },
      );
      if (value == null) return;
      final port = int.tryParse(value.trim());
      await controller.update((o) => o.copyWith(mixedPort: () => port));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ref.watch(vpnPlatformProvider).corePlatform == CorePlatform.android)
          ListTile(
            leading: const Icon(Icons.apps_rounded),
            title: Text(l10n.splitTunnel),
            subtitle: Text(switch (options.perAppMode) {
              PerAppMode.off => l10n.splitTunnelOff,
              PerAppMode.include =>
                '${l10n.splitTunnelInclude} · ${l10n.appsSelected(formatNumber(options.perAppPackages.length, locale: context.localeCode))}',
              PerAppMode.exclude =>
                '${l10n.splitTunnelExclude} · ${l10n.appsSelected(formatNumber(options.perAppPackages.length, locale: context.localeCode))}',
            }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SplitTunnelPage()),
            ),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.alt_route_rounded),
          title: Text(l10n.bypassIran),
          subtitle: Text(l10n.bypassIranHint),
          value: options.bypassIran,
          onChanged: (v) => controller.update((o) => o.copyWith(bypassIran: v)),
        ),
        ListTile(
          leading: const Icon(Icons.public_rounded),
          title: Text(l10n.remoteDns),
          subtitle: Text(options.remoteDns, textDirection: TextDirection.ltr),
          onTap: () => editDns(remote: true),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(l10n.directDns),
          subtitle: Text(options.directDns, textDirection: TextDirection.ltr),
          onTap: () => editDns(remote: false),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.six_k_outlined),
          title: Text(l10n.enableIpv6),
          subtitle: Text(l10n.enableIpv6Hint),
          value: options.enableIpv6,
          onChanged: (v) => controller.update((o) => o.copyWith(enableIpv6: v)),
        ),
        ListTile(
          leading: const Icon(Icons.lan_outlined),
          title: Text(l10n.mixedPort),
          subtitle: Text(l10n.mixedPortHint),
          trailing: Text(
            options.mixedPort?.toString() ?? l10n.disabled,
            textDirection: TextDirection.ltr,
          ),
          onTap: editPort,
        ),
        ListTile(
          leading: const Icon(Icons.fingerprint_rounded),
          title: Text(l10n.fingerprint),
          subtitle: Text(l10n.fingerprintHint),
          trailing: DropdownButton<String?>(
            value: options.defaultFingerprint,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.disabled)),
              for (final fp in _fingerprints)
                DropdownMenuItem(value: fp, child: Text(fp)),
            ],
            onChanged: (v) => controller.update(
              (o) => o.copyWith(defaultFingerprint: () => v),
            ),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.speed_rounded),
          title: Text(l10n.blockQuic),
          subtitle: Text(l10n.blockQuicHint),
          value: options.blockQuic,
          onChanged: (v) => controller.update((o) => o.copyWith(blockQuic: v)),
        ),
        ListTile(
          leading: const Icon(Icons.call_split_rounded),
          title: Text(l10n.tlsFragment),
          subtitle: Text(l10n.tlsFragmentHint),
          trailing: DropdownButton<TlsFragmentMode>(
            value: options.tlsFragment,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: TlsFragmentMode.off,
                child: Text(l10n.disabled),
              ),
              DropdownMenuItem(
                value: TlsFragmentMode.record,
                child: Text(l10n.fragmentLight),
              ),
              DropdownMenuItem(
                value: TlsFragmentMode.tcp,
                child: Text(l10n.fragmentStrong),
              ),
            ],
            onChanged: (v) =>
                controller.update((o) => o.copyWith(tlsFragment: v)),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.merge_type_rounded),
          title: Text(l10n.mux),
          subtitle: Text(l10n.muxHint),
          value: options.mux,
          onChanged: (v) => controller.update((o) => o.copyWith(mux: v)),
        ),
        if (options.mux)
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: 72,
              end: 24,
            ),
            title: Text(l10n.muxProtocol),
            trailing: DropdownButton<String>(
              value: options.muxProtocol,
              underline: const SizedBox.shrink(),
              items: [
                for (final p in muxProtocols)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) =>
                  controller.update((o) => o.copyWith(muxProtocol: v)),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: Text(l10n.tunStack),
          trailing: DropdownButton<String>(
            value: options.tunStack,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in CoreOptions.tunStacks)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => controller.update((o) => o.copyWith(tunStack: v)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(l10n.logLevel),
          trailing: DropdownButton<String>(
            value: options.logLevel,
            underline: const SizedBox.shrink(),
            items: [
              for (final level in CoreOptions.logLevels)
                DropdownMenuItem(value: level, child: Text(level)),
            ],
            onChanged: (v) => controller.update((o) => o.copyWith(logLevel: v)),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(l10n.resetDefaults),
            onPressed: controller.reset,
          ),
        ),
      ],
    );
  }
}
