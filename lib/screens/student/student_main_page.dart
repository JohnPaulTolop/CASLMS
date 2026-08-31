import 'package:flutter/material.dart';

import 'modules_page.dart';
import 'progress_page.dart';
import 'student_assignments_page.dart';
import 'student_dashboard_page.dart';
import 'student_profile_page.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({
    super.key,
  });

  @override
  State<StudentMainScreen> createState() =>
      _StudentMainScreenState();
}

class _StudentMainScreenState
    extends State<StudentMainScreen> {
  static const Color primaryBlue =
      Color(
    0xFF1769FF,
  );

  int _selectedIndex = 0;

  // ============================================================
  // STABLE PAGE INSTANCES
  //
  // These are created once instead of being recreated
  // every time StudentMainScreen rebuilds.
  // ============================================================

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      StudentDashboardScreen(
        onNavigateToTab: _onItemTapped,
      ),

      const ModulesScreen(),

      const StudentAssignmentsScreen(),

      const ProgressScreen(),

      const StudentProfileScreen(),
    ];
  }

  // ============================================================
  // CHANGE TAB
  // ============================================================

  void _onItemTapped(
    int index,
  ) {
    if (!mounted) {
      return;
    }

    if (index < 0 ||
        index >= _pages.length) {
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF7F9FC,
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ),

          child: IndexedStack(
            index: _selectedIndex,

            children: _pages,
          ),
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),

              blurRadius: 10,

              offset: const Offset(
                0,
                -4,
              ),
            ),
          ],
        ),

        child: SafeArea(
          child: Center(
            heightFactor: 1,

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),

              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor:
                      Colors.transparent,

                  highlightColor:
                      Colors.transparent,
                ),

                child: BottomNavigationBar(
                  backgroundColor:
                      Colors.white,

                  elevation: 0,

                  currentIndex:
                      _selectedIndex,

                  onTap: _onItemTapped,

                  selectedItemColor:
                      primaryBlue,

                  unselectedItemColor:
                      Colors.grey[400],

                  showSelectedLabels:
                      true,

                  showUnselectedLabels:
                      true,

                  selectedFontSize: 10,

                  unselectedFontSize: 10,

                  type:
                      BottomNavigationBarType.fixed,

                  iconSize: 24,

                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.home_rounded,
                      ),
                      label: 'Home',
                    ),

                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.folder_rounded,
                      ),
                      label: 'Modules',
                    ),

                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.assignment_rounded,
                      ),
                      label: 'Tasks',
                    ),

                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.timeline_rounded,
                      ),
                      label: 'Progress',
                    ),

                    BottomNavigationBarItem(
                      icon: Icon(
                        Icons.person_outline_rounded,
                      ),
                      label: 'Profile',
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