import 'package:flutter/material.dart';

import '../../../core/utils/context_ext.dart';

typedef CiscoForm = ({
  String address,
  String username,
  String password,
  String group,
  String name,
});

/// The details a Cisco AnyConnect (ocserv) seller hands out. Returns `null`
/// on cancel.
Future<CiscoForm?> ciscoDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _CiscoDialog());

class _CiscoDialog extends StatefulWidget {
  const _CiscoDialog();

  @override
  State<_CiscoDialog> createState() => _CiscoDialogState();
}

class _CiscoDialogState extends State<_CiscoDialog> {
  final _address = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _group = TextEditingController();
  final _name = TextEditingController();
  var _obscure = true;
  String? _addressError;
  String? _usernameError;

  @override
  void dispose() {
    for (final c in [_address, _username, _password, _group, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final address = _address.text.trim();
    final uri = Uri.tryParse(
      address.contains('://') ? address : 'https://$address',
    );
    setState(() {
      _addressError = uri == null || uri.host.isEmpty || address.contains(' ')
          ? l10n.invalidValue
          : null;
      _usernameError = _username.text.trim().isEmpty
          ? l10n.loginUsernameRequired
          : null;
    });
    if (_addressError != null || _usernameError != null) return;
    Navigator.pop(context, (
      address: address,
      username: _username.text.trim(),
      password: _password.text,
      group: _group.text.trim(),
      name: _name.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    TextField field(
      TextEditingController controller,
      String label, {
      String? hint,
      String? error,
      bool ltr = true,
      bool autofocus = false,
      TextInputType? keyboard,
    }) => TextField(
      controller: controller,
      autofocus: autofocus,
      autocorrect: false,
      keyboardType: keyboard,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintTextDirection: TextDirection.ltr,
        errorText: error,
      ),
    );

    return AlertDialog(
      title: Text(l10n.ciscoAdd),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(
                _address,
                l10n.ciscoServer,
                hint: 'vpn.example.com:443',
                error: _addressError,
                autofocus: true,
                keyboard: TextInputType.url,
              ),
              const SizedBox(height: 12),
              field(_username, l10n.loginUsername, error: _usernameError),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
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
              ),
              const SizedBox(height: 12),
              field(_group, l10n.ciscoGroup),
              const SizedBox(height: 12),
              field(_name, l10n.name, ltr: false),
            ],
          ),
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
