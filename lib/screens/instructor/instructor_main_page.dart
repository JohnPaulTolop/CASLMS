import '../shared/notification_destination_page.dart';

import 'package:flutter/material.dart';

import 'instructor_teaching_assistant_page.dart';
import '../shared/caslms_help_page.dart';
import '../shared/role_navigation_bar.dart';
import 'instructor_messages_page.dart';

import 'instructor_ui.dart';

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
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CaslmsOnboarding.maybeShow(context, role: 'instructor');
    });
  }

  int _selectedIndex = 0;
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
  final Set<int> _openedTabs = <int>{};

  void _onItemTapped(int index) {
    setState(() {
      _destinationVisible = false;
      _selectedIndex = index;
      _openedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      InstructorDashboardScreen(onNavigateToTab: _onItemTapped),
      const InstructorClassesScreen(),
      const InstructorGradingScreen(),
      const InstructorAnalyticsScreen(),
      const InstructorProfileScreen(),
      _openedTabs.contains(5)
          ? const InstructorMessagesScreen()
          : const SizedBox.shrink(),
      _openedTabs.contains(6)
          ? const InstructorTeachingAssistantScreen()
          : const SizedBox.shrink(),
    ];

    return instructorScaffold(
      context: context,
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        // Center horizontally handles the max-width alignment safely
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(
            index: _selectedIndex,
            children: List.generate(
              pages.length,
              (index) =>
                  _destinationVisible &&
                      _notificationDestination != null &&
                      index == _destinationIndex
                  ? _notificationDestination
                  : pages[index],
            ),
          ),
        ),
      ),
      bottomNavigationBar: RoleNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _onItemTapped,
        instructor: true,
      ),
    );
  }
}
