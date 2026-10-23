import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/campus_auth_service.dart';
import '../../services/student_profile_service.dart';
import '../shared/dashboard_hover.dart';

class StudentProfileEditor extends StatefulWidget {
  const StudentProfileEditor({
    super.key,
    required this.profile,
    required this.onSaved,
    required this.onBusyChanged,
    required this.onResetPassword,
    this.photoBusy = false,
    this.resetBusy = false,
  });
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onSaved;
  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onResetPassword;
  final bool photoBusy, resetBusy;

  @override
  State<StudentProfileEditor> createState() => _StudentProfileEditorState();
}

class _StudentProfileEditorState extends State<StudentProfileEditor> {
  static const _blue = Color(0xFF1769FF);
  static const _ink = Color(0xFF10182F);
  static const _muted = Color(0xFF68738A);
  static const _border = Color(0xFFE6EAF0);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _service = StudentProfileService();
  int? _year;
  String? _pendingEmail;
  bool _saving = false;
  bool _checking = false;
  bool _confirming = false;

  int? _storedYear(Map<String, dynamic> profile) {
    final raw = profile['yearLevel'];
    final year = raw is num ? raw.toInt() : int.tryParse('$raw');
    return year != null && year >= 1 && year <= 4 ? year : null;
  }

  String _storedName(Map<String, dynamic> profile) =>
      (profile['displayName'] ?? profile['name'] ?? '').toString().trim();
  String get _registeredEmail =>
      (widget.profile['email'] ?? '').toString().trim().toLowerCase();
  bool get _basicDirty =>
      _name.text.trim() != _storedName(widget.profile) ||
      _year != _storedYear(widget.profile);
  bool get _emailDirty =>
      _email.text.trim().toLowerCase() != _registeredEmail &&
      _email.text.trim().toLowerCase() != _pendingEmail;
  bool get _dirty => _basicDirty || _emailDirty;
  bool get _locked =>
      _saving ||
      _checking ||
      _confirming ||
      widget.photoBusy ||
      widget.resetBusy;

  @override
  void initState() {
    super.initState();
    _name.text = _storedName(widget.profile);
    _email.text = _registeredEmail;
    _year = _storedYear(widget.profile);
  }

  @override
  void didUpdateWidget(covariant StudentProfileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep unsaved edits when a photo or another profile value changes.
    if (_name.text.trim() == _storedName(oldWidget.profile)) {
      _name.text = _storedName(widget.profile);
    }
    if (_year == _storedYear(oldWidget.profile)) {
      _year = _storedYear(widget.profile);
    }
    final oldEmail = (oldWidget.profile['email'] ?? '')
        .toString()
        .toLowerCase();
    if (_email.text.trim().toLowerCase() == oldEmail ||
        _pendingEmail == _registeredEmail) {
      _email.text = _registeredEmail;
    }
    if (_pendingEmail == _registeredEmail) _pendingEmail = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB91C1C) : _blue,
        ),
      );
  }

  String _authError(FirebaseAuthException error) => switch (error.code) {
    'wrong-password' ||
    'invalid-credential' ||
    'user-mismatch' => 'Incorrect password. Please try again.',
    'email-already-in-use' =>
      'This email is already linked to another account.',
    'invalid-email' => 'Enter a valid email address.',
    'requires-recent-login' || 'user-token-expired' || 'invalid-user-token' =>
      'Please sign in again to finish changing your email.',
    'too-many-requests' => 'Too many requests. Wait a moment and try again.',
    'network-request-failed' => 'Check your connection and retry.',
    _ => 'Unable to send the email confirmation. Please try again.',
  };

  Future<void> _save() async {
    if (_locked || !(_form.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final year = _year!;
    final changeEmail = _emailDirty;
    String? password;
    if (changeEmail) {
      setState(() => _confirming = true);
      widget.onBusyChanged(true);
      password = await showDialog<String>(
        context: context,
        builder: (_) => _EmailPasswordDialog(email: email),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      widget.onBusyChanged(false);
      if (password == null) return;
    }
    setState(() => _saving = true);
    widget.onBusyChanged(true);
    var saved = false;
    try {
      await _service.save(displayName: name, yearLevel: year);
      saved = true;
      if (!mounted) return;
      widget.onSaved({
        ...widget.profile,
        'name': name,
        'displayName': name,
        'yearLevel': year,
      });
      if (changeEmail) {
        await _service.requestEmailChange(email: email, password: password!);
        if (!mounted) return;
        setState(() => _pendingEmail = email);
        _message(
          'Profile saved. Open the link sent to your new email, then select Check email verification.',
        );
      } else {
        _message('Your profile changes have been saved.');
      }
    } on FirebaseAuthException catch (error) {
      _message(
        '${saved ? 'Profile saved. ' : ''}${_authError(error)}',
        error: true,
      );
    } on StudentProfileException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message(
        saved
            ? 'Profile saved, but the email request failed. Please retry the email change.'
            : 'Unable to save your profile. Check your connection and retry.',
        error: true,
      );
    } finally {
      password = null;
      if (mounted) {
        setState(() => _saving = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _checkEmail() async {
    if (_locked || _basicDirty) return;
    setState(() => _checking = true);
    widget.onBusyChanged(true);
    try {
      final auth = CampusAuthService();
      await auth.checkVerifiedProfileEmail();
      final profile = await auth.getCurrentProfile();
      if (!mounted || profile == null) return;
      final verifiedEmail = (profile['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final changed = verifiedEmail != _registeredEmail;
      widget.onSaved(profile);
      if (changed) {
        setState(() {
          _email.text = verifiedEmail;
          _pendingEmail = null;
        });
        _message(
          'Your verified email has been updated. Password resets will use this address.',
        );
      } else {
        _message(
          'No confirmed email change found. Open the link in your new inbox first. You may need to sign in again afterward.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _message(_authError(error), error: true);
    } on CampusAuthException catch (error) {
      _message(error.message, error: true);
    } catch (_) {
      _message(
        'Unable to check email verification. Please sign in again and retry.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        widget.onBusyChanged(false);
      }
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _muted, size: 21),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts_outlined, color: _blue),
              SizedBox(width: 10),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your display name, year level and email in one place.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final fields = <Widget>[
                TextFormField(
                  controller: _name,
                  enabled: !_locked,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: _decoration(
                    'Display name',
                    Icons.person_outline_rounded,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                TextFormField(
                  key: ValueKey(widget.profile['universityId']),
                  initialValue: (widget.profile['universityId'] ?? '')
                      .toString(),
                  readOnly: true,
                  decoration: _decoration('Student ID', Icons.badge_outlined)
                      .copyWith(
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                        ),
                        helperText: 'Your school-issued login ID. Contact admin for corrections.',
                        helperMaxLines: 2,
                      ),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey(_year),
                  initialValue: _year,
                  isExpanded: true,
                  decoration: _decoration('Year level', Icons.school_outlined),
                  hint: const Text('Select year level'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1st Year')),
                    DropdownMenuItem(value: 2, child: Text('2nd Year')),
                    DropdownMenuItem(value: 3, child: Text('3rd Year')),
                    DropdownMenuItem(value: 4, child: Text('4th Year')),
                  ],
                  onChanged: _locked
                      ? null
                      : (value) => setState(() => _year = value),
                  validator: (value) =>
                      value == null ? 'Select your year level.' : null,
                ),
                TextFormField(
                  controller: _email,
                  enabled: !_locked,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration:
                      _decoration(
                        'Email / Gmail address',
                        Icons.mail_outline_rounded,
                      ).copyWith(
                        helperText: 'A new address must be confirmed using its email link.',
                        helperMaxLines: 2,
                      ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final email = (value ?? '').trim().toLowerCase();
                    return !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email) ||
                            email.endsWith('@caslms.app')
                        ? 'Enter a valid personal email address.'
                        : null;
                  },
                ),
              ];
              return Wrap(
                spacing: 20,
                runSpacing: 18,
                children: fields
                    .map(
                      (field) => SizedBox(
                        width: box.maxWidth >= 650
                            ? (box.maxWidth - 20) / 2
                            : box.maxWidth,
                        child: field,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          if (_pendingEmail != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Confirmation sent to $_pendingEmail. Your registered email remains $_registeredEmail until you confirm the new address.',
                style: const TextStyle(color: _ink, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: _locked || _basicDirty ? null : _checkEmail,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const Text('Check email verification'),
              ),
              TextButton.icon(
                onPressed: _locked ? null : widget.onResetPassword,
                icon: widget.resetBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded, size: 18),
                label: Text(
                  widget.resetBusy ? 'Sending reset link...' : 'Reset Password',
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DashboardHover(
                enabled: !_locked && _dirty,
                accent: _blue,
                lift: 1.5,
                borderRadius: BorderRadius.circular(12),
                child: FilledButton.icon(
                  onPressed: _locked || !_dirty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size(170, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 19),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                ),
              ),
              Text(
                _dirty
                    ? 'You have unsaved changes.'
                    : _pendingEmail != null
                    ? 'Email confirmation pending.'
                    : 'Your profile is up to date.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EmailPasswordDialog extends StatefulWidget {
  const _EmailPasswordDialog({required this.email});
  final String email;
  @override
  State<_EmailPasswordDialog> createState() => _EmailPasswordDialogState();
}

class _EmailPasswordDialogState extends State<_EmailPasswordDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hidden = true;
  bool _submitted = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_submitted && _form.currentState?.validate() == true) {
      _submitted = true;
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm email change'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a verification link to ${widget.email}. Your registered address changes only after you confirm it.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _password,
                autofocus: true,
                obscureText: _hidden,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Current password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Enter your current password.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Confirm & Save')),
    ],
  );
}
