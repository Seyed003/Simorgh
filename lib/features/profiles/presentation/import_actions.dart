import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/utils/qr_decoder.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/profiles_controller.dart';
import '../data/subscription_client.dart';
import '../domain/profiles_state.dart';
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

  Future<void> addSubscription() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _SubscriptionDialog(),
    );
    if (result == null || !context.mounted) return;
    final (url, name) = result;
    await _run(() => _controller.addSubscription(url, name: name));
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
        context.showSnack(l10n.nothingToImport);
        return;
      }
      final parts = [
        l10n.importedCount(outcome.added),
        if (outcome.skipped > 0) l10n.skippedCount(outcome.skipped),
      ];
      context.showSnack(parts.join(' · '));
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
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
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
              decoration: InputDecoration(
                labelText: l10n.subscriptionUrl,
                hintText: 'https://example.com/sub/…',
                hintTextDirection: TextDirection.ltr,
                errorText: _error,
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
