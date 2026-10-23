import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pushed admin views remain protected if another tab changes the session.
class AdminAccessGuard extends StatefulWidget {
  const AdminAccessGuard({super.key, required this.child});
  final Widget child;
  @override
  State<AdminAccessGuard> createState() => _AdminAccessGuardState();
}

class _AdminAccessGuardState extends State<AdminAccessGuard> {
  late final _auth = FirebaseAuth.instance.idTokenChanges();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _auth,
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, session) {
      final user = session.data;
      if (user == null) {
        return const Scaffold(
          body: AdminEmpty(
            title: 'Administrator access required',
            message:
                'Return to login and sign in with an administrator account.',
          ),
        );
      }
      return _AdminProfileAccess(
        key: ValueKey(user.uid),
        uid: user.uid,
        child: widget.child,
      );
    },
  );
}

class _AdminProfileAccess extends StatefulWidget {
  const _AdminProfileAccess({
    super.key,
    required this.uid,
    required this.child,
  });
  final String uid;
  final Widget child;
  @override
  State<_AdminProfileAccess> createState() => _AdminProfileAccessState();
}

class _AdminProfileAccessState extends State<_AdminProfileAccess> {
  late final _profile = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data?.data();
          if (snapshot.hasError ||
              data?['role'] != 'admin' ||
              data?['status'] != 'active') {
            return const Scaffold(
              body: AdminEmpty(
                title: 'Administrator access required',
                message: 'This account cannot open the admin file library.',
              ),
            );
          }
          return widget.child;
        },
      );
}

abstract final class AdminUi {
  static const accent = Color(0xFF4F46E5);
  static const background = Color(0xFFF5F7FC);
  static const ink = Color(0xFF17233D);
  static const muted = Color(0xFF69778F);
  static const border = Color(0xFFE4E9F3);
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AdminUi.border),
    ),
    child: child,
  );
}

class AdminBadge extends StatelessWidget {
  const AdminBadge(this.label, {super.key, this.color = AdminUi.accent});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class AdminPageHeading extends StatelessWidget {
  const AdminPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });
  final String title, subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AdminUi.ink,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AdminUi.muted, height: 1.5),
          ),
        ],
      );
      if (box.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: text),
          const SizedBox(width: 16),
          Wrap(spacing: 8, children: actions),
        ],
      );
    },
  );
}

class AdminNotice extends StatelessWidget {
  const AdminNotice(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AdminPanel(
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, color: AdminUi.muted),
        Text(message, style: const TextStyle(color: AdminUi.muted)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
    child: Column(
      children: [
        Icon(icon, color: AdminUi.accent, size: 38),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AdminUi.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AdminUi.muted, height: 1.5),
        ),
      ],
    ),
  );
}
