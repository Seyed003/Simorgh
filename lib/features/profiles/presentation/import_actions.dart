import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/singbox/protocols/openconnect.dart';
import '../../../core/singbox/proxy_config.dart';
import '../../../core/singbox/subscription_parser.dart';
import '../../../core/singbox/subscription_url.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/qr_decoder.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/incoming_import.dart';
import '../application/profiles_controller.dart';
import '../data/certificate_probe.dart';
import '../data/subscription_client.dart';
import '../domain/profile.dart';
import '../domain/profiles_state.dart';
import 'cisco_dialog.dart';
import 'login_dialog.dart';
import 'qr_scanner_page.dart';

/// Camera scanning uses the Android camera stack; desktop users import a
/// screenshot or image file instead.
bool get cameraScanSupported => Platform.isAndroid;

/// UI flows that turn user input into imported profiles.
class ImportActions {
  const ImportActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  ProfilesController get _controller => ref.read(profilesProvider.notifier);

  Future<void> fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (text.isEmpty) {
      context.showSnack(context.l10n.clipboardEmpty);
      return;
    }
    await _run(() => _controller.importText(text));
  }

  Future<void> scanQr() async {
    final text = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (text == null || !context.mounted) return;
    await _run(() => _controller.importText(text));
  }

  Future<void> fromImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || !context.mounted) return;
    final bytes = await files.first.readAsBytes();
    if (!context.mounted) return;
    final text = await withProgress(
      context,
      () => Isolate.run(() => QrDecoder.decodeImageBytes(bytes)),
    );
    if (!context.mounted) return;
    if (text == null) {
      context.showSnack(context.l10n.qrNotFound);
      return;
    }
    await _run(() => _controller.importText(text));
  }

  Future<void> pasteManually() async {
    final l10n = context.l10n;
    final text = await textInputDialog(
      context,
      title: l10n.pasteManually,
      hint: l10n.pasteHint,
      multiline: true,
      ltr: true,
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await _run(() => _controller.importText(text));
  }

  /// A config file: an OpenVPN profile (.ovpn), a sing-box/Xray JSON or a
  /// text file of links.
  Future<void> fromFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !context.mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    if (bytes.length > 512 * 1024) {
      context.showSnack(context.l10n.nothingToImport);
      return;
    }
    final name = file.name.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
    await _run(
      () => _controller.importText(
        utf8.decode(bytes, allowMalformed: true),
        name: name,
      ),
    );
  }

  /// A Cisco AnyConnect (ocserv) server from its address and login. A
  /// self-signed certificate is shown to the user and, once accepted,
  /// pinned, like the Cisco app's "connect anyway".
  Future<void> addCisco() async {
    final l10n = context.l10n;
    final form = await ciscoDialog(context);
    if (form == null || !context.mounted) return;
    ProxyConfig build({String? pin}) => openConnectConfig(
      address: form.address,
      username: form.username,
      password: form.password,
      group: form.group,
      name: form.name,
      pin: pin,
    );
    final ProxyConfig draft;
    try {
      draft = build();
    } on LinkParseException catch (e) {
      context.showSnack(l10n.importFailed(e.message));
      return;
    }
    final certificate = await withProgress(
      context,
      () => probeCertificate(draft.server, draft.port),
    );
    if (!context.mounted) return;
    var config = draft;
    if (certificate == null) {
      final ok = await confirmDialog(
        context,
        title: l10n.ciscoUnreachableTitle,
        message: l10n.ciscoUnreachable(draft.server),
        confirmLabel: l10n.add,
      );
      if (!ok) return;
    } else if (!certificate.trusted) {
      final ok = await confirmDialog(
        context,
        title: l10n.ciscoUntrustedTitle,
        message: l10n.ciscoUntrusted(certificate.subject, certificate.pin),
        confirmLabel: l10n.ciscoTrust,
        destructive: true,
      );
      if (!ok) return;
      config = build(pin: certificate.pin);
    }
    if (!context.mounted) return;
    await _controller.addAndSelect(config);
    if (context.mounted) context.showSnack(l10n.importedCount(1));
  }

  /// Asks for the username and password [profile] still lacks.
  Future<void> login(Profile profile) async {
    final config = profile.config;
    final login = await loginDialog(
      context,
      server: '${profile.name} · ${config.server}',
      username: config.username,
    );
    if (login == null) return;
    await _controller.replaceConfig(
      profile.id,
      config.withLogin(login.username, login.password),
    );
  }

  Future<void> addSubscription() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _SubscriptionDialog(),
    );
    if (result == null || !context.mounted) return;
    final (url, name) = result;
    await _run(() => _controller.addSubscription(url, name: name));
  }

  /// A link tapped in another app, or text shared to this one: asks first,
  /// so a web page cannot add configs behind the user's back.
  Future<void> fromIncoming(IncomingImport incoming) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.importLinkTitle,
      message: switch (incoming) {
        IncomingConfigs(:final count, :final text, :final name) => [
          l10n.importConfigsQuestion(count),
          // What exactly: a page could push a server of its own.
          for (final p in SubscriptionParser.parse(
            text,
            name: name,
          ).proxies.take(3))
            '• ${p.protocol.displayName} · ${p.name} · ${p.server}',
          if (count > 3) '…',
        ].join('\n'),
        IncomingSubscription(:final host, :final url) => [
          l10n.importSubscriptionQuestion(host),
          if (isPlainHttp(url)) l10n.subscriptionHttpWarning,
        ].join('\n\n'),
      },
      confirmLabel: l10n.add,
    );
    if (!ok || !context.mounted) return;
    await _run(
      () => switch (incoming) {
        IncomingConfigs(:final text, :final name) => _controller.importText(
          text,
          name: name,
        ),
        IncomingSubscription(:final url, :final name) =>
          _controller.addSubscription(url, name: name),
      },
    );
  }

  Future<void> updateSubscription(String id) async {
    await _run(() => _controller.updateSubscription(id));
  }

  Future<void> updateAllSubscriptions() async {
    final l10n = context.l10n;
    final failures = await withProgress(
      context,
      _controller.updateAllSubscriptions,
    );
    if (!context.mounted) return;
    context.showSnack(
      failures.isEmpty
          ? l10n.updateAllSubscriptions
          : l10n.subscriptionUpdateFailed(failures.join('، ')),
    );
  }

  Future<void> _run(Future<ImportOutcome> Function() task) async {
    final l10n = context.l10n;
    try {
      final outcome = await withProgress(context, task);
      if (!context.mounted) return;
      if (outcome.added == 0) {
        context.showSnack(
          outcome.skipped == 1 && outcome.skipReason != null
              ? l10n.importFailed(outcome.skipReason!)
              : l10n.nothingToImport,
        );
        return;
      }
      final parts = [
        l10n.importedCount(outcome.added),
        if (outcome.skipped > 0) l10n.skippedCount(outcome.skipped),
      ];
      context.showSnack(parts.join(' · '));
      // OpenVPN profiles that ask for a login without carrying one.
      for (final profile in outcome.profiles) {
        if (!profile.config.needsLogin || !context.mounted) continue;
        await login(profile);
      }
    } on SubscriptionException catch (e) {
      if (context.mounted) context.showSnack(l10n.importFailed(e.message));
    } on Exception catch (e) {
      if (context.mounted) context.showSnack(l10n.importFailed(e.toString()));
    }
  }
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog();

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _url.text.trim();
    if (subscriptionUri(url) == null) {
      setState(() => _error = context.l10n.invalidUrl);
      return;
    }
    Navigator.pop(context, (url, _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addSubscription),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.subscriptionUrl,
                hintText: 'https://example.com/sub/…',
                hintTextDirection: TextDirection.ltr,
                errorText: _error,
                helperText: isPlainHttp(_url.text)
                    ? l10n.subscriptionHttpWarning
                    : null,
                helperMaxLines: 4,
                helperStyle: TextStyle(color: StatusColors.of(context).error),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.subscriptionName),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.add)),
      ],
    );
  }
}
