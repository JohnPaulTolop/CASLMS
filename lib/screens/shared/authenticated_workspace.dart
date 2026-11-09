import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/activity_log_service.dart';
import '../../services/notification_service.dart';
import 'notification_inbox.dart';
import 'workspace_shell.dart';

/// Provides only account chrome. Existing SessionGate remains the access gate.
class AuthenticatedWorkspace extends StatefulWidget {
  const AuthenticatedWorkspace({
    super.key,
    required this.child,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.role = 'Student',
    this.profileIndex = 4,
    this.inboxIndex,
  });
  final Widget child;
  final List<WorkspaceDestination> destinations;
  final int selectedIndex, profileIndex;
  final int? inboxIndex;
  final ValueChanged<int> onSelected;
  final String role;
  @override
  State<AuthenticatedWorkspace> createState() => _AuthenticatedWorkspaceState();
}

class _AuthenticatedWorkspaceState extends State<AuthenticatedWorkspace> {
  late final _user = FirebaseAuth.instance.currentUser;
  late final _profile = _user == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .snapshots();
  late final _notifications = NotificationService().watchMyNotifications();
  bool _signingOut = false;

  void _inbox() {
    if (widget.inboxIndex != null) {
      widget.onSelected(widget.inboxIndex!);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationInboxScreen(),
        ),
      );
    }
  }

  Future<void> _logout() async {
    if (_signingOut) return;
    final confirmed = await confirmWorkspaceLogout(context);
    if (confirmed != true || !mounted) return;
    _signingOut = true;
    try {
      await ActivityLogService().signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to log out. Please try again.')),
        );
      }
    } finally {
      _signingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, snapshot) {
          final profile = snapshot.data?.data();
          final name =
              (profile?['name'] ??
                      profile?['displayName'] ??
                      _user?.displayName ??
                      widget.role)
                  .toString();
          final photo =
              (profile?['photoUrl'] ?? profile?['photoURL'] ?? _user?.photoURL)
                  ?.toString();
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notifications,
            builder: (context, notices) => WorkspaceShell(
              destinations: widget.destinations,
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onSelected,
              onInbox: _inbox,
              onLogout: _logout,
              role: widget.role,
              name: name,
              photoUrl: photo,
              profileIndex: widget.profileIndex,
              notificationsAvailable: !notices.hasError,
              unreadCount: (notices.data ?? [])
                  .where((n) => n['isRead'] != true)
                  .length,
              child: widget.child,
            ),
          );
        },
      );
}
