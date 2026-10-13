import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/context_ext.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single (or multi-line) text input dialog. Returns `null` on cancel.
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hint,
  String? label,
  bool multiline = false,
  bool ltr = false,
  TextInputType? keyboardType,
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      hint: hint,
      label: label,
      multiline: multiline,
      ltr: ltr,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    this.initialValue,
    this.hint,
    this.label,
    required this.multiline,
    required this.ltr,
    this.keyboardType,
    this.validator,
  });

  final String title;
  final String? initialValue;
  final String? hint;
  final String? label;
  final bool multiline;
  final bool ltr;
  final TextInputType? keyboardType;
  final String? Function(String value)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: widget.multiline ? 4 : 1,
          maxLines: widget.multiline ? 10 : 1,
          keyboardType: widget.multiline
              ? TextInputType.multiline
              : widget.keyboardType,
          textDirection: widget.ltr ? TextDirection.ltr : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            labelText: widget.label,
            errorText: _error,
            hintTextDirection: widget.ltr ? TextDirection.ltr : null,
          ),
          onSubmitted: widget.multiline ? null : (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}

/// Shows a blocking progress dialog while [task] runs, with [status] as
/// its text when given.
Future<T> withProgress<T>(
  BuildContext context,
  Future<T> Function() task, {
  ValueListenable<String>? status,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: status == null
                    ? Text(context.l10n.working)
                    : ValueListenableBuilder(
                        valueListenable: status,
                        builder: (_, text, _) => Text(text),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}
