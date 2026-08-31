import 'package:flutter/material.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center( // Center horizontally handles the max-width alignment safely
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, 
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0, // Ensures the nav bar doesn't stretch vertically
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent, 
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: Colors.teal.shade600,
                  unselectedItemColor: Colors.grey[400],
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  type: BottomNavigationBarType.fixed, 
                  iconSize: 24,
                  items: const [
                    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Icon(Icons.dashboard_rounded)), label: 'Dashboard'),
                    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Icon(Icons.class_rounded)), label: 'Classes'),
                    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Icon(Icons.checklist_rounded)), label: 'Grading'),
                    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Icon(Icons.insights_rounded)), label: 'Analytics'),
                    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Icon(Icons.person_outline_rounded)), label: 'Profile'),
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