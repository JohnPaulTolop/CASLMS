import '../shared/notification_inbox.dart';
import '../shared/notification_destination_page.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/learner_assistant_page.dart';
import '../shared/authenticated_workspace.dart';
import '../shared/workspace_shell.dart';
import '../shared/calendar_page.dart';
import 'student_messages_page.dart';

import 'modules_page.dart';
import 'student_results_page.dart';
import 'student_assignments_page.dart';
import 'student_dashboard_page.dart';
import 'student_profile_page.dart';
import 'student_notes_page.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key, this.notificationId});
  final String? notificationId;

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  int _selectedIndex = 0;
  final _resultsSelection = ValueNotifier<int>(0);
  bool _destinationVisible = true;
  final _notificationKey = GlobalKey();
  late final Widget? _notificationDestination = widget.notificationId == null
      ? null
      : NotificationDestinationScreen(
          key: _notificationKey,
          notificationId: widget.notificationId!,
          onTab: (index) {
            if (mounted) {
              setState(() {
                _selectedIndex = index == 7 || index == 8 ? 3 : index;
                _openedTabs.add(index);
              });
            }
          },
        );
  final Set<int> _openedTabs = <int>{};
  late final List<Widget> _pages;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;

  final Set<String> _knownNotificationIds = {};
  bool _notificationBaselineLoaded = false;

  @override
  void initState() {
    super.initState();

    _pages = [
      StudentDashboardScreen(onNavigateToTab: _onItemTapped),
      const ModulesScreen(),
      const StudentAssignmentsScreen(),
      StudentResultsScreen(selection: _resultsSelection),
      const StudentProfileScreen(),
      const StudentMessagesScreen(),
      const LearnerAssistantScreen(role: 'student'),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const NotificationInboxScreen(),
      const CalendarScreen(role: 'student'),
      const StudentNotesScreen(),
    ];

    _startNotificationPopups();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _resultsSelection.dispose();
    _tabAnimation.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 7 || index == 8) {
      _resultsSelection.value = index == 7 ? 1 : 2;
      index = 3;
    }
    if (!mounted ||
        index < 0 ||
        index >= _pages.length ||
        index == _selectedIndex &&
            !(_destinationVisible && widget.notificationId != null)) {
      return;
    }

    setState(() {
      _destinationVisible = false;
      _selectedIndex = index;
      _openedTabs.add(index);
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      _tabAnimation.forward(from: 0);
    }
  }

  void _startNotificationPopups() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted) return;

            // Show only committed notifications from the server.
            if (snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites) {
              return;
            }

            // Existing inbox messages must not all pop up at login.
            if (!_notificationBaselineLoaded) {
              _knownNotificationIds.addAll(
                snapshot.docs.map((document) => document.id),
              );
              _notificationBaselineLoaded = true;
              return;
            }

            for (final document in snapshot.docs) {
              if (!_knownNotificationIds.add(document.id)) continue;

              final data = document.data();

              if (data['isRead'] == true) continue;

              final title = (data['title'] ?? 'New notification').toString();
              final message = (data['message'] ?? '').toString();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      '$title\n$message',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    action: SnackBarAction(
                      label: 'Open',
                      onPressed: () =>
                          NotificationNavigation.open(context, document.id),
                    ),
                    duration: const Duration(seconds: 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Notification listener failed: $error');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedWorkspace(
      destinations: studentDestinations,
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      inboxIndex: 9,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _tabAnimation,
          curve: Curves.easeOutCubic,
        ),
        child: IndexedStack(
          index: _destinationVisible && _notificationDestination != null
              ? _pages.length
              : _selectedIndex,
          children: [
            for (var index = 0; index < _pages.length; index++)
              if (index == 0 || _openedTabs.contains(index))
                _pages[index]
              else
                const SizedBox.shrink(),
            // Keep the destination in one slot when its sidebar selection changes.
            if (_notificationDestination != null) _notificationDestination,
          ],
        ),
      ),
    );
  }
}
