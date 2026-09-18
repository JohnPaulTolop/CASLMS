import 'package:flutter/material.dart';

import '../shared/learner_assistant_page.dart';
import '../shared/role_navigation_bar.dart';
import 'instructor_messages_page.dart';

import 'instructor_ui.dart';

import 'instructor_dashboard_page.dart';
import 'instructor_grading_page.dart';
import 'instructor_analytics_page.dart';
import 'instructor_classes_page.dart';
import 'instructor_profile_page.dart';

class InstructorMainScreen extends StatefulWidget {
  const InstructorMainScreen({super.key});

  @override
  State<InstructorMainScreen> createState() => _InstructorMainScreenState();
}

class _InstructorMainScreenState extends State<InstructorMainScreen> {
  int _selectedIndex = 0;
  final Set<int> _openedTabs = <int>{};

  void _onItemTapped(int index) {
    setState(() {
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
          ? const LearnerAssistantScreen(role: 'instructor')
          : const SizedBox.shrink(),
    ];

    return instructorScaffold(
      context: context,
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        // Center horizontally handles the max-width alignment safely
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(index: _selectedIndex, children: pages),
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
