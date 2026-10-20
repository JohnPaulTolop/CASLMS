import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/campus_auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});
  final String email;
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final _auth = CampusAuthService();
  Timer? _poll;
  bool _checking = false;
  bool _sending = false;
  DateTime? _nextResend;
  String _message =
      'Open the confirmation link in your email. Your dashboard will unlock after verification.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check(silent: true);
    });
    _poll = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || _sending) return;
    setState(() => _checking = true);
    try {
      final verified = await _auth.checkStudentEmailVerification();
      if (mounted && !verified && !silent) {
        setState(
          () => _message = 'Your email is not verified yet. Check your inbox and spam folder, then try again.',
        );
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_sending || _checking) return;
    if (_nextResend != null && DateTime.now().isBefore(_nextResend!)) {
      setState(
        () =>
            _message = 'Please wait a minute before requesting another email.',
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _auth.resendVerificationEmail();
      if (mounted) {
        setState(() {
          _nextResend = DateTime.now().add(const Duration(minutes: 1));
          _message =
              'Confirmation email sent. Check your inbox and spam folder.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Verify your email'),
      automaticallyImplyLeading: false,
      actions: [
        TextButton(
          onPressed: () => _auth.signOut(),
          child: const Text('Log Out'),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: Color(0xFF1769FF),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Confirm your email address',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.email, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(_message, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _checking || _sending ? null : () => _check(),
                    child: Text(
                      _checking ? 'Checking...' : 'I have verified my email',
                    ),
                  ),
                  TextButton(
                    onPressed: _checking || _sending ? null : _resend,
                    child: Text(
                      _sending ? 'Sending...' : 'Resend confirmation email',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
