import 'package:flutter/material.dart';

import '../../services/campus_auth_service.dart';
import '../../services/password_reset_service.dart';

class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({
    super.key,
    required this.authService,
    required this.resetService,
    this.initialCampusId = '',
  });
  final CampusAuthService authService;
  final PasswordResetService resetService;
  final String initialCampusId;
  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final _form = GlobalKey<FormState>();
  late final _id = TextEditingController(text: widget.initialCampusId);
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.resetService.requestPasswordReset(
        campusId: _id.text,
        email: _email.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error is PasswordResetException
              ? error.message
              : 'Unable to request a password reset. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Reset your password'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your student or faculty ID and the Gmail address linked to your account.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('reset-id'),
                  controller: _id,
                  enabled: !_sending,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ID number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your ID number.'
                      : !widget.authService.isValidCampusId(value.trim())
                      ? 'Enter a valid ID number.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('reset-email'),
                  controller: _email,
                  enabled: !_sending,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    labelText: 'Registered Gmail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your registered Gmail.'
                      : !widget.authService.isValidEmail(value.trim())
                      ? 'Enter a valid Gmail address.'
                      : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send reset link'),
        ),
      ],
    ),
  );
}
