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
import 'admin_ui.dart';
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
    _ => const SizedBox.shrink(),
  };
  Widget _content() => IndexedStack(
    index: _selectedIndex,
    children: List.generate(
      9,
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

  Future<void> _more() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  'Administration',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              ..._destinations
                  .where((d) => d.$1 > 2)
                  .map(
                    (d) => ListTile(
                      leading: Icon(d.$3),
                      title: Text(d.$2),
                      selected: _selectedIndex == d.$1,
                      onTap: () => Navigator.pop(context, d.$1),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
    if (mounted && chosen != null) _onItemTapped(chosen);
  }

  @override
  Widget build(BuildContext context) => AdminScope(
    catalog: _catalog,
    child: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: AdminUi.accent),
        scaffoldBackgroundColor: AdminUi.background,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final desktop = box.maxWidth >= 1100;
          return Scaffold(
            backgroundColor: AdminUi.background,
            body: SafeArea(
              child: Row(
                children: [
                  if (desktop)
                    Container(
                      width: 224,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(color: AdminUi.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(22, 24, 22, 22),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage(
                                    'assets/images/CASlogo.jpg',
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CAS LMS',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AdminUi.ink,
                                        ),
                                      ),
                                      Text(
                                        'ADMINISTRATION',
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: 1.2,
                                          color: AdminUi.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 18,
                              ),
                              children: _destinations
                                  .map(
                                    (d) => Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        selected: _selectedIndex == d.$1,
                                        selectedTileColor: AdminUi.accent
                                            .withValues(alpha: .08),
                                        selectedColor: AdminUi.accent,
                                        leading: Icon(d.$3, size: 22),
                                        title: Text(
                                          d.$2,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onTap: () => _onItemTapped(d.$1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Samar State University\nCollege of Arts and Sciences',
                              style: TextStyle(
                                color: AdminUi.muted,
                                fontSize: 11,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: _content(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: desktop
                ? null
                : NavigationBar(
                    selectedIndex: _selectedIndex <= 2 ? _selectedIndex : 3,
                    onDestinationSelected: (index) =>
                        index == 3 ? _more() : _onItemTapped(index),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline),
                        label: 'Users',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.school_outlined),
                        label: 'Courses',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        label: 'More',
                      ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}
