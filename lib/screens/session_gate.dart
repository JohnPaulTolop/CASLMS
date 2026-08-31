import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/campus_auth_service.dart';

import 'admin/admin_main_page.dart';
import 'instructor/instructor_main_page.dart';
import 'landing_page.dart';
import 'student/student_main_page.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  static final CampusAuthService _authService =
      CampusAuthService();

  @override
  Widget build(
    BuildContext context,
  ) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,

      // Immediately use an already authenticated Firebase user
      // when the app is opened again.
      initialData: _authService.currentUser,

      builder: (
        context,
        authSnapshot,
      ) {
        if (authSnapshot.connectionState ==
                ConnectionState.waiting &&
            authSnapshot.data == null) {
          return const _LoadingScreen();
        }

        final User? user =
            authSnapshot.data;

        // ======================================================
        // NOT LOGGED IN
        // ======================================================

        if (user == null) {
          return const LandingScreen();
        }

        // ======================================================
        // LOGGED IN
        //
        // Validate Firestore role/status.
        // ======================================================

        return _AuthenticatedRoleGate(
          key: ValueKey(
            user.uid,
          ),
          userId: user.uid,
        );
      },
    );
  }
}

// ============================================================
// AUTHENTICATED ROLE GATE
// ============================================================

class _AuthenticatedRoleGate
    extends StatefulWidget {
  const _AuthenticatedRoleGate({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<_AuthenticatedRoleGate>
      createState() =>
          _AuthenticatedRoleGateState();
}

class _AuthenticatedRoleGateState
    extends State<_AuthenticatedRoleGate> {
  final CampusAuthService _authService =
      CampusAuthService();

  late final Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();

    // Only create this Future once for the current UID.
    // This prevents repeated Firestore role reads caused
    // by normal widget rebuilds.
    _roleFuture =
        _getValidatedRole();
  }

  // ============================================================
  // VALIDATE ACCOUNT
  // ============================================================

  Future<String?>
      _getValidatedRole() async {
    final Map<String, dynamic>? profile =
        await _authService
            .getCurrentProfile();

    if (profile == null) {
      await _authService.signOut();

      return null;
    }

    // ==========================================================
    // VALIDATE UID
    // ==========================================================

    final String profileUid =
        (profile['uid'] ?? '')
            .toString()
            .trim();

    if (profileUid.isNotEmpty &&
        profileUid != widget.userId) {
      await _authService.signOut();

      return null;
    }

    // ==========================================================
    // VALIDATE STATUS
    // ==========================================================

    final String status =
        (profile['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (status != 'active') {
      await _authService.signOut();

      return null;
    }

    // ==========================================================
    // VALIDATE ROLE
    // ==========================================================

    final String role =
        (profile['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    const Set<String> allowedRoles = {
      'student',
      'instructor',
      'admin',
    };

    if (!allowedRoles.contains(
      role,
    )) {
      await _authService.signOut();

      return null;
    }

    return role;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<String?>(
      future: _roleFuture,

      builder: (
        context,
        roleSnapshot,
      ) {
        if (roleSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (roleSnapshot.hasError) {
          return _SessionErrorScreen(
            onRetry: () async {
              await _authService.signOut();
            },
          );
        }

        // ======================================================
        // ROLE ROUTING
        // ======================================================

        switch (roleSnapshot.data) {
          case 'student':
            return const StudentMainScreen();

          case 'instructor':
            return const InstructorMainScreen();

          case 'admin':
            return const AdminMainScreen();

          default:
            return const LandingScreen();
        }
      },
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _LoadingScreen
    extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Scaffold(
      backgroundColor:
          Color(0xFFF8FAFD),

      body: Center(
        child:
            CircularProgressIndicator(
          color: Color(
            0xFF1769FF,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SESSION ERROR
// ============================================================

class _SessionErrorScreen
    extends StatelessWidget {
  const _SessionErrorScreen({
    required this.onRetry,
  });

  final Future<void> Function()
      onRetry;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF8FAFD,
      ),

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons
                    .error_outline_rounded,

                color: Color(
                  0xFFFF4B4B,
                ),

                size: 46,
              ),

              const SizedBox(
                height: 14,
              ),

              const Text(
                'Unable to load your CASLMS session.',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color:
                      Color(
                    0xFF10182F,
                  ),

                  fontSize: 16,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Please return to the login screen and try again.',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color:
                      Color(
                    0xFF68738A,
                  ),

                  fontSize: 12.5,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              ElevatedButton(
                onPressed: () async {
                  await onRetry();
                },

                child: const Text(
                  'Return to Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}