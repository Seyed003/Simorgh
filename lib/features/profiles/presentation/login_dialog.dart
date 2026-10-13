import 'package:flutter/material.dart';

import '../../../core/utils/context_ext.dart';

/// Asks for the username and password of an OpenVPN or Cisco server.
/// Returns `null` on cancel.
Future<({String username, String password})?> loginDialog(
  BuildContext context, {
  required String server,
  String username = '',
}) => showDialog(
  context: context,
  builder: (_) => _LoginDialog(server: server, username: username),
);

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.server, required this.username});

  final String server;
  final String username;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  late final _username = TextEditingController(text: widget.username);
  final _password = TextEditingController();
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error = context.l10n.loginUsernameRequired);
      return;
    }
    Navigator.pop(context, (username: username, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.loginTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.server,
              textDirection: TextDirection.ltr,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              autofocus: widget.username.isEmpty,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.loginUsername,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              autofocus: widget.username.isNotEmpty,
              obscureText: _obscure,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.loginPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
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
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
