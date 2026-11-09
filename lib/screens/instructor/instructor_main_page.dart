import '../shared/notification_destination_page.dart';

import 'package:flutter/material.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../services/instructor_workspace_context.dart';

import 'instructor_teaching_assistant_page.dart';
import '../shared/caslms_help_page.dart';
import '../shared/authenticated_workspace.dart';
import '../shared/workspace_shell.dart';
import '../shared/calendar_page.dart';
import 'instructor_messages_page.dart';

import 'instructor_dashboard_page.dart';
import 'instructor_grading_page.dart';
import 'instructor_analytics_page.dart';
import 'instructor_classes_page.dart';
import 'instructor_profile_page.dart';

class InstructorMainScreen extends StatefulWidget {
  const InstructorMainScreen({super.key, this.notificationId});
  final String? notificationId;

  @override
  State<InstructorMainScreen> createState() => _InstructorMainScreenState();
}

class _InstructorMainScreenState extends State<InstructorMainScreen> {
  StreamSubscription<User?>? _contextAuth;
  @override
  void initState() {
    super.initState();
    InstructorWorkspaceContext.instance.bindUser(
      FirebaseAuth.instance.currentUser?.uid,
    );
    _contextAuth = FirebaseAuth.instance.authStateChanges().listen((user) {
      InstructorWorkspaceContext.instance.bindUser(user?.uid);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CaslmsOnboarding.maybeShow(context, role: 'instructor');
    });
  }

  int _selectedIndex = 0;
  @override
  void dispose() {
    _contextAuth?.cancel();
    InstructorWorkspaceContext.instance.bindUser(null);
    super.dispose();
  }

  int _destinationIndex = 0;
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
                _selectedIndex = index;
                _destinationIndex = index;
              });
            }
          },
        );
  final Set<int> _openedTabs = <int>{0};

  void _onItemTapped(int index) {
    setState(() {
      _destinationVisible = false;
      _selectedIndex = index;
      _openedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<WidgetBuilder> pages = [
      (_) => InstructorDashboardScreen(onNavigateToTab: _onItemTapped),
      (_) => const InstructorClassesScreen(),
      (_) => const InstructorGradingScreen(),
      (_) => const InstructorAnalyticsScreen(),
      (_) => const InstructorProfileScreen(),
      (_) => const InstructorMessagesScreen(),
      (_) => const InstructorTeachingAssistantScreen(),
      (_) => const CalendarScreen(role: 'instructor'),
    ];

    return AuthenticatedWorkspace(
      role: 'Instructor',
      destinations: instructorDestinations,
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      child: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          pages.length,
          (index) =>
              _destinationVisible &&
                  _notificationDestination != null &&
                  index == _destinationIndex
              ? _notificationDestination
              : TickerMode(
                  enabled: index == _selectedIndex,
                  child: _openedTabs.contains(index) || index == _selectedIndex
                      ? pages[index](context)
                      : const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}
