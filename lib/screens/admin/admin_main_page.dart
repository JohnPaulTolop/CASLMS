import 'package:flutter/material.dart';

import 'admin_courses_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_instructor_approvals_page.dart';
import 'admin_settings_page.dart';
import 'admin_users_page.dart';

class AdminMainScreen
    extends StatefulWidget {
  const AdminMainScreen({
    super.key,
  });

  @override
  State<AdminMainScreen>
      createState() =>
          _AdminMainScreenState();
}

class _AdminMainScreenState
    extends State<AdminMainScreen> {
  static const Color adminTheme =
      Color(0xFF4F46E5);

  int _selectedIndex = 0;

  void _onItemTapped(
    int index,
  ) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Widget> pages = [
      AdminDashboardScreen(
        onNavigateToTab:
            _onItemTapped,
      ),

      // Keep the original indexes unchanged.
      const AdminUsersScreen(),
      const AdminCoursesScreen(),
      const AdminSettingsScreen(),

      // New instructor approval page.
      const AdminInstructorApprovalsScreen(),
    ];

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1200,
          ),
          child: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar:
          Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.05,
              ),
              blurRadius: 10,
              offset:
                  const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1200,
              ),
              child:
                  BottomNavigationBar(
                currentIndex:
                    _selectedIndex,
                onTap:
                    _onItemTapped,
                selectedItemColor:
                    adminTheme,
                unselectedItemColor:
                    Colors.grey.shade400,
                type:
                    BottomNavigationBarType
                        .fixed,
                backgroundColor:
                    Colors.white,
                elevation: 0,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                selectedLabelStyle:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons
                          .dashboard_rounded,
                    ),
                    label:
                        'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons
                          .manage_accounts_rounded,
                    ),
                    label: 'Users',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons
                          .library_books_rounded,
                    ),
                    label: 'Courses',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons
                          .settings_suggest_rounded,
                    ),
                    label: 'Settings',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons
                          .how_to_reg_rounded,
                    ),
                    label: 'Approvals',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}