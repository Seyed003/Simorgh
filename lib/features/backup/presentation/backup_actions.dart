import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/backup_service.dart';
import '../domain/app_backup.dart';

/// Saving and restoring a backup file from the settings.
class BackupActions {
  const BackupActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> save() async {
    final l10n = context.l10n;
    final backup = await ref.read(backupServiceProvider).create();
    final saved = await FilePicker.saveFile(
      fileName: backup.fileName,
      bytes: utf8.encode(backup.encode()),
      mimeType: 'application/json',
      dialogTitle: l10n.backupSave,
    );
    if (saved != null && context.mounted) context.showSnack(l10n.backupSaved);
  }

  Future<void> restore() async {
    final l10n = context.l10n;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty || !context.mounted) return;
    final AppBackup backup;
    try {
      backup = AppBackup.decode(utf8.decode(await files.first.readAsBytes()));
    } on FormatException {
      if (context.mounted) context.showSnack(l10n.backupInvalid);
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l10n.backupRestore,
      message: l10n.backupRestoreHint,
      confirmLabel: l10n.backupRestore,
    );
    if (!ok || !context.mounted) return;
    final added = await withProgress(
      context,
      () => ref.read(backupServiceProvider).restore(backup),
    );
    if (context.mounted) {
      context.showSnack(
        l10n.backupRestored(formatNumber(added, locale: context.localeCode)),
      );
    }
  }
}
