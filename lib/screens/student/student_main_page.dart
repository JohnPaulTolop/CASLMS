import '../shared/notification_inbox.dart';
import '../shared/notification_destination_page.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../shared/learner_assistant_page.dart';
import '../shared/role_navigation_bar.dart';
import 'student_messages_page.dart';

import 'modules_page.dart';
import 'progress_page.dart';
import 'student_assignments_page.dart';
import 'student_dashboard_page.dart';
import 'student_profile_page.dart';
import 'activities_scores_page.dart';
import 'posted_grades_page.dart';

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
  int _destinationIndex = 0;
  bool _destinationVisible = true;
  final _notificationKey = GlobalKey();
  late final Widget? _notificationDestination = widget.notificationId == null ? null
      : NotificationDestinationScreen(key:_notificationKey, notificationId: widget.notificationId!, onTab: (index) {
          if (mounted) setState(() { _selectedIndex = index; _destinationIndex = index; });
        });
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
      const ProgressScreen(),
      const StudentProfileScreen(),
      const StudentMessagesScreen(),
      const LearnerAssistantScreen(role: 'student'),
      const ActivitiesScoresScreen(),
      const PostedGradesScreen(),
    ];

    _startNotificationPopups();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tabAnimation.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!mounted ||
        index < 0 ||
        index >= _pages.length ||
        index == _selectedIndex && !(_destinationVisible && widget.notificationId != null)) {
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
                    action: SnackBarAction(label:'Open',onPressed:() => NotificationNavigation.open(context,document.id)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _tabAnimation,
              curve: Curves.easeOutCubic,
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: List.generate(
                _pages.length,
                (index) => index < 5 || _openedTabs.contains(index) || (_destinationVisible && _notificationDestination != null && index == _destinationIndex)
                    ? (_destinationVisible && _notificationDestination != null && index == _destinationIndex ? _notificationDestination : _pages[index])
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: RoleNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _onItemTapped,
        instructor: false,
      ),
    );
  }
}
