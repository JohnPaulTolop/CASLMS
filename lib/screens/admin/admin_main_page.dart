import '../shared/authenticated_workspace.dart';
import '../shared/calendar_page.dart';

import 'package:flutter/material.dart';

import '../../services/admin_catalog.dart';
import '../shared/notification_destination_page.dart';
import 'admin_activity_logs_page.dart';
import 'admin_caslms_assistant_page.dart';
import 'admin_courses_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_files_page.dart';
import 'admin_instructor_approvals_page.dart';
import 'admin_settings_page.dart';
import 'admin_system_reports_page.dart';

import 'admin_users_page.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key, this.notificationId});
  final String? notificationId;
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final _catalog = AdminCatalog();
  final _opened = <int>{0};
  int _selectedIndex = 0, _destinationIndex = 0;
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
                _opened.add(index);
              });
            }
          },
        );
  // Existing indexes 0–5 are preserved for dashboard callbacks/notifications.
  static const _destinations = <(int, String, IconData)>[
    (0, 'Overview', Icons.space_dashboard_outlined),
    (1, 'Users', Icons.manage_accounts_outlined),
    (2, 'Courses', Icons.school_outlined),
    (6, 'Instructor files', Icons.folder_copy_outlined),
    (7, 'Activity logs', Icons.history_rounded),
    (4, 'Instructor approvals', Icons.how_to_reg_outlined),
    (8, 'Reports', Icons.analytics_outlined),
    (9, 'Calendar', Icons.calendar_month_outlined),
    (5, 'AI Assistant', Icons.smart_toy_outlined),
    (3, 'Settings', Icons.settings_outlined),
  ];
  @override
  void initState() {
    super.initState();
    _catalog.start();
  }

  @override
  void dispose() {
    _catalog.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() {
    _destinationVisible = false;
    _selectedIndex = index;
    _opened.add(index);
  });
  Widget _page(int index) => switch (index) {
    0 => AdminDashboardScreen(onNavigateToTab: _onItemTapped),
    1 => const AdminUsersScreen(),
    2 => const AdminCoursesScreen(),
    3 => const AdminSettingsScreen(),
    4 => const AdminInstructorApprovalsScreen(),
    5 => const AdminCaslmsAssistantScreen(),
    6 => const AdminFilesScreen(),
    7 => const AdminActivityLogsScreen(),
    8 => const AdminSystemReportsScreen(),
    9 => const CalendarScreen(role: 'admin'),
    _ => const SizedBox.shrink(),
  };
  Widget _content() => IndexedStack(
    index: _selectedIndex,
    children: List.generate(
      10,
      (index) =>
          _destinationVisible &&
              _notificationDestination != null &&
              index == _destinationIndex
          ? _notificationDestination
          : _opened.contains(index)
          ? KeyedSubtree(key: ValueKey('admin-tab-$index'), child: _page(index))
          : const SizedBox.shrink(),
    ),
  );

  @override
  Widget build(BuildContext context) => AdminScope(
    catalog: _catalog,
    child: AuthenticatedWorkspace(
      role: 'Administrator',
      profileIndex: 3,
      destinations: [
        for (final d in _destinations) (index: d.$1, label: d.$2, icon: d.$3),
      ],
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      child: _content(),
    ),
  );
}
