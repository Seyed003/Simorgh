import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/builder/core_options.dart';
import '../../../core/singbox/builder/dns_server.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/core_options_controller.dart';

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
      final value = await textInputDialog(
        context,
        title: remote ? l10n.remoteDns : l10n.directDns,
        initialValue: remote ? options.remoteDns : options.directDns,
        hint: l10n.dnsAddressHint,
        ltr: true,
        keyboardType: TextInputType.url,
        validator: validateDns,
      );
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
