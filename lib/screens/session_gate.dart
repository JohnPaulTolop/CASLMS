import '../core/app_colors.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/campus_auth_service.dart';
import 'student/email_verification_page.dart';
import 'student/student_main_page.dart';

import 'admin/admin_main_page.dart';
import 'instructor/instructor_main_page.dart';
import 'landing_page.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, this.notificationId, this.authService, this.isUiRedesignMode = false});
  final String? notificationId;
  final CampusAuthService? authService;
  final bool isUiRedesignMode;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final CampusAuthService _authService =
      widget.authService ?? CampusAuthService();
  late final Stream<User?> _session = _authService.authStateChanges;

  @override
  Widget build(BuildContext context) {
    if (widget.isUiRedesignMode) {
      return StudentMainScreen(notificationId: widget.notificationId);
    }

    return StreamBuilder<User?>(
      stream: _session,
      initialData: _authService.currentUser,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting &&
            authSnapshot.data == null) {
          return const _LoadingScreen();
        }

        final User? user = authSnapshot.data;

        if (user == null) {
          return const LandingScreen();
        }

        return _AuthenticatedRoleGate(
          key: ValueKey(user.uid),
          userId: user.uid,
          notificationId: widget.notificationId,
          authService: _authService,
        );
      },
    );
  }
}

class _AuthenticatedRoleGate extends StatefulWidget {
  const _AuthenticatedRoleGate({
    super.key,
    required this.userId,
    this.notificationId,
    required this.authService,
  });
  final String? notificationId;
  final String userId;
  final CampusAuthService authService;

  @override
  State<_AuthenticatedRoleGate> createState() => _AuthenticatedRoleGateState();
}

class _AuthenticatedRoleGateState extends State<_AuthenticatedRoleGate> {
  // This state is keyed by UID. Token renewal must reuse the same stream and
  // preserve the mounted dashboard, current tab and unsaved profile form.
  late final Stream<Map<String, dynamic>?> _profile = widget.authService
      .watchProfile(widget.userId);
  CampusAuthService get _authService => widget.authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profile,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting &&
            !profileSnapshot.hasData) {
          return const _LoadingScreen();
        }

        if (profileSnapshot.hasError) {
          return _AccountStateScreen(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            title: 'Unable to load your account',
            message: 'CASLMS could not load your profile. Check your internet connection and try again.',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        final Map<String, dynamic>? profile = profileSnapshot.data;

        if (profile == null) {
          return _AccountStateScreen(
            icon: Icons.person_off_outlined,
            iconColor: AppColors.error,
            title: 'Profile not found',
            message: 'Your authentication account exists, but its CASLMS profile could not be found.',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        final String profileUid = (profile['uid'] ?? '').toString().trim();

        if (profileUid.isNotEmpty && profileUid != widget.userId) {
          return _AccountStateScreen(
            icon: Icons.security_rounded,
            iconColor: AppColors.error,
            title: 'Invalid account profile',
            message:
                'The loaded profile does not match the authenticated account.',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        final String role = (profile['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String status = (profile['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (role == 'student' &&
            profile['emailVerificationRequired'] == true &&
            (status == 'pending_verification' ||
                (status == 'active' &&
                    _authService.currentUser?.emailVerified != true))) {
          return EmailVerificationScreen(
            email: (profile['email'] ?? '').toString(),
          );
        }

        if (role == 'instructor' && status == 'pending') {
          return _InstructorPendingScreen(
            profile: profile,
            onSignOut: _authService.signOut,
          );
        }

        if (role == 'instructor' && status == 'denied') {
          final String reason = (profile['denialReason'] ?? '')
              .toString()
              .trim();

          return _AccountStateScreen(
            icon: Icons.cancel_outlined,
            iconColor: AppColors.error,
            title: 'Application denied',
            message: reason.isEmpty
                ? 'Your instructor application was not approved. Contact the CASLMS administrator for assistance.'
                : 'Your instructor application was not approved.\n\nReason: $reason',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        if (status == 'suspended') {
          return _AccountStateScreen(
            icon: Icons.block_rounded,
            iconColor: AppColors.error,
            title: 'Account suspended',
            message: 'Your CASLMS account is currently suspended. Contact the administrator for assistance.',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        if (status != 'active') {
          return _AccountStateScreen(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.error,
            title: 'Account unavailable',
            message: 'This CASLMS account is not currently active.',
            buttonText: 'Return to Login',
            onPressed: _authService.signOut,
          );
        }

        switch (role) {
          case 'student':
            return StudentMainScreen(notificationId: widget.notificationId);

          case 'instructor':
            return InstructorMainScreen(notificationId: widget.notificationId);

          case 'admin':
            return AdminMainScreen(notificationId: widget.notificationId);

          default:
            return _AccountStateScreen(
              icon: Icons.security_rounded,
              iconColor: AppColors.error,
              title: 'Invalid account role',
              message: 'This account does not have a valid CASLMS role.',
              buttonText: 'Return to Login',
              onPressed: _authService.signOut,
            );
        }
      },
    );
  }
}

class _InstructorPendingScreen extends StatelessWidget {
  const _InstructorPendingScreen({
    required this.profile,
    required this.onSignOut,
  });

  final Map<String, dynamic> profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final String name = (profile['name'] ?? 'Instructor').toString().trim();

    final String facultyId = (profile['universityId'] ?? '').toString().trim();

    final String email = (profile['email'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'CASLMS',
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await onSignOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4DC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.amber,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Waiting for approval',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name.isEmpty
                          ? 'Your instructor application is being reviewed.'
                          : 'Hello $name, your instructor application is being reviewed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _ProfileRow(label: 'Faculty ID', value: facultyId),
                          const Divider(height: 24),
                          _ProfileRow(label: 'Email', value: email),
                          const Divider(height: 24),
                          const _ProfileRow(
                            label: 'Status',
                            value: 'Pending review',
                            valueColor: AppColors.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'You will automatically receive instructor access after an administrator approves your application. A decision will also be sent to your registered email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'This page updates automatically',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.darkText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountStateScreen extends StatelessWidget {
  const _AccountStateScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonText;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 54),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          await onPressed();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(buttonText),
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
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );
  }
}
