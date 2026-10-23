import '../shared/dashboard_hover.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/admin_records.dart';
import '../../services/admin_catalog.dart';
import '../shared/notification_inbox.dart';
import 'admin_ai_gateway_page.dart';
import 'admin_file_details_page.dart';
import 'admin_instructor_approvals_page.dart';
import 'admin_ui.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onNavigateToTab});
  final ValueChanged<int>? onNavigateToTab;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final _recentFiles = FirebaseFirestore.instance
      .collection('moduleResources')
      .where('deliveryType', isEqualTo: 'uploaded_file')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();
  late final _failedFiles = FirebaseFirestore.instance
      .collection('moduleResources')
      .where('aiProcessingStatus', isEqualTo: 'failed')
      .limit(5)
      .snapshots();
  late final _recentLogs = FirebaseFirestore.instance
      .collection('activityLogs')
      .orderBy('createdAt', descending: true)
      .limit(6)
      .snapshots();

  void _go(int index) => widget.onNavigateToTab?.call(index);
  @override
  Widget build(BuildContext context) {
    final catalog = AdminScope.of(context);
    final admin = catalog.users[FirebaseAuth.instance.currentUser?.uid];
    final students = catalog.users.values
        .where((u) => u['role'] == 'student' && u['status'] == 'active')
        .length;
    final instructors = catalog.users.values
        .where((u) => u['role'] == 'instructor' && u['status'] == 'active')
        .length;
    final activeCourses = catalog.courses.values
        .where((c) => c['status'] == 'active')
        .length;
    final ownershipIssues = catalog.courses.entries.where((entry) {
      final owner = catalog.users[adminText(entry.value['instructorId'])];
      return entry.value['status'] == 'active' &&
          (owner == null ||
              owner['role'] != 'instructor' ||
              owner['status'] != 'active');
    }).toList();
    final unverified = catalog.users.values
        .where(
          (u) =>
              u['role'] == 'student' && u['status'] == 'pending_verification',
        )
        .length;
    return Scaffold(
      backgroundColor: AdminUi.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AdminPageHeading(
              title: 'Administration',
              subtitle:
                  'Welcome, ${admin?['name'] ?? 'Administrator'}. Your campus overview is updated live.',
              actions: [
                DashboardHover(
                  accent: AdminUi.accent,
                  lift: 1.5,
                  borderRadius: BorderRadius.circular(12),
                  child: const NotificationBell(),
                ),
                DashboardHover(
                  accent: AdminUi.accent,
                  lift: 1.5,
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    tooltip: 'Refresh directory',
                    onPressed: catalog.start,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (catalog.error != null) ...[
              AdminNotice(catalog.error!, onRetry: catalog.start),
              const SizedBox(height: 18),
            ],
            if (catalog.loading) const LinearProgressIndicator(),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 850
                    ? 4
                    : box.maxWidth >= 480
                    ? 2
                    : 1;
                final width = (box.maxWidth - 14 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _metric(
                      'Active students',
                      students,
                      Icons.groups_outlined,
                      Colors.blue,
                      () => _go(1),
                    ),
                    _metric(
                      'Active instructors',
                      instructors,
                      Icons.badge_outlined,
                      Colors.teal,
                      () => _go(1),
                    ),
                    _metric(
                      'Active courses',
                      activeCourses,
                      Icons.school_outlined,
                      AdminUi.accent,
                      () => _go(2),
                    ),
                    _metric(
                      'Awaiting approval',
                      catalog.pendingApplications.length,
                      Icons.how_to_reg_outlined,
                      Colors.orange,
                      () => _go(4),
                    ),
                  ].map((card) => SizedBox(width: width, child: card)).toList(),
                );
              },
            ),
            const SizedBox(height: 26),
            const Text(
              'Needs attention',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AdminUi.ink,
              ),
            ),
            const SizedBox(height: 12),
            DashboardHover(
              accent: AdminUi.accent,
              lift: 0,
              showBorder: false,
              child: AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (catalog.pendingApplications.isNotEmpty) ...[
                      _attention(
                        Icons.person_add_alt_1_outlined,
                        '${catalog.pendingApplications.length} instructor registration(s) awaiting review',
                        'Approve or reject applications after reviewing their details.',
                        () => _go(4),
                      ),
                      ...catalog.pendingApplications.entries
                          .take(3)
                          .map(
                            (e) => DashboardHover(
                              accent: AdminUi.accent,
                              lift: 2,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.only(left: 42),
                                title: Text(adminText(e.value['name'])),
                                subtitle: Text(
                                  adminText(e.value['universityId']),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminInstructorApprovalsScreen(
                                          applicationId: e.key,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                    if (ownershipIssues.isNotEmpty)
                      _attention(
                        Icons.person_off_outlined,
                        '${ownershipIssues.length} active course(s) need an active instructor',
                        ownershipIssues
                            .take(3)
                            .map((e) => adminText(e.value['code']))
                            .join(' · '),
                        () => _go(2),
                      ),
                    if (unverified > 0)
                      _attention(
                        Icons.mark_email_unread_outlined,
                        '$unverified student account(s) awaiting email verification',
                        'Review pending accounts in Users. Verification remains required.',
                        () => _go(1),
                      ),
                    if (!catalog.loading &&
                        catalog.error == null &&
                        catalog.pendingApplications.isEmpty &&
                        ownershipIssues.isEmpty &&
                        unverified == 0)
                      const AdminEmpty(
                        title: 'No account or course issues found',
                        message: 'Pending approvals, unverified accounts and course ownership issues will appear here.',
                        icon: Icons.task_alt_rounded,
                      ),
                    if (catalog.loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Checking accounts and courses…'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, box) {
                final panels = [_uploads(catalog), _activity()];
                if (box.maxWidth < 900) {
                  return Column(
                    children: [
                      panels[0],
                      const SizedBox(height: 18),
                      panels[1],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 18),
                    Expanded(child: panels[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            _failedUploads(catalog),
            const SizedBox(height: 22),
            DashboardHover(
              accent: AdminUi.accent,
              lift: 0,
              showBorder: false,
              child: AdminPanel(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DashboardHover(
                      accent: AdminUi.accent,
                      lift: 1.5,
                      borderRadius: BorderRadius.circular(12),
                      child: OutlinedButton.icon(
                        onPressed: () => _go(8),
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('System reports'),
                      ),
                    ),
                    DashboardHover(
                      accent: AdminUi.accent,
                      lift: 1.5,
                      borderRadius: BorderRadius.circular(12),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminAIGatewayScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.memory_outlined),
                        label: const Text('AI processing monitor'),
                      ),
                    ),
                    DashboardHover(
                      accent: AdminUi.accent,
                      lift: 1.5,
                      borderRadius: BorderRadius.circular(12),
                      child: OutlinedButton.icon(
                        onPressed: () => _go(3),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Platform settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => DashboardHover(
    accent: color,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminUi.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const Spacer(),
                  const Icon(
                    Icons.north_east_rounded,
                    color: AdminUi.muted,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                (AdminScope.of(context).loading ||
                        AdminScope.of(context).error != null)
                    ? '—'
                    : '$value',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AdminUi.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: AdminUi.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _attention(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => DashboardHover(
    accent: AdminUi.accent,
    lift: 2,
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.deepOrange),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
  Widget _panelHeader(String title, String action, VoidCallback onTap) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AdminUi.ink,
          ),
        ),
      ),
      DashboardHover(
        accent: AdminUi.accent,
        lift: 1.5,
        borderRadius: BorderRadius.circular(12),
        child: TextButton(onPressed: onTap, child: Text(action)),
      ),
    ],
  );
  Widget _uploads(AdminCatalog catalog) => DashboardHover(
    accent: AdminUi.accent,
    lift: 0,
    showBorder: false,
    child: AdminPanel(
      child: Column(
        children: [
          _panelHeader('Recent uploads', 'View library', () => _go(6)),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recentFiles,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const AdminEmpty(
                  title: 'Uploads unavailable',
                  message: 'Open the file library to retry.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.data!.docs.isEmpty) {
                return const AdminEmpty(
                  title: 'No uploaded materials yet',
                  message: 'The newest instructor uploads appear here.',
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final file = doc.data();
                  final owner = catalog.users[adminText(file['createdBy'])];
                  final course = catalog.courses[adminText(file['courseId'])];
                  return DashboardHover(
                    accent: AdminUi.accent,
                    lift: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.description_outlined,
                        color: AdminUi.accent,
                      ),
                      title: Text(
                        adminText(file['title']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${owner?['name'] ?? 'Account unavailable'} · ${course?['code'] ?? 'Course unavailable'}\n${adminTimestamp(file['createdAt'])}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminFileDetailsScreen(
                            fileId: doc.id,
                            catalog: catalog,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
  Widget _activity() => DashboardHover(
    accent: AdminUi.accent,
    lift: 0,
    showBorder: false,
    child: AdminPanel(
      child: Column(
        children: [
          _panelHeader('Recent activity', 'View logs', () => _go(7)),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recentLogs,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const AdminEmpty(
                  title: 'Activity unavailable',
                  message: 'Open Activity logs to retry.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.data!.docs.isEmpty) {
                return const AdminEmpty(
                  title: 'Activity history starts here',
                  message: 'Future sign-ins, logout requests, course creations and uploads will be recorded.',
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final row = doc.data();
                  return DashboardHover(
                    accent: AdminUi.accent,
                    lift: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.history_rounded,
                        color: AdminUi.accent,
                      ),
                      title: Text(
                        '${row['actorName']} · ${adminEventLabels[adminText(row['type'])] ?? row['type']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        adminTimestamp(row['createdAt']),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _go(7),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
  Widget _failedUploads(AdminCatalog catalog) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _failedFiles,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AdminNotice(
              'AI processing alerts are unavailable. Open the AI processing monitor to check.',
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }
          return DashboardHover(
            accent: AdminUi.accent,
            lift: 0,
            showBorder: false,
            child: AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learning materials needing AI review',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'File access is separate from AI processing. Review these materials in the AI monitor.',
                    style: TextStyle(color: AdminUi.muted, fontSize: 12),
                  ),
                  ...snapshot.data!.docs.map(
                    (doc) => DashboardHover(
                      accent: AdminUi.accent,
                      lift: 2,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                        ),
                        title: Text(adminText(doc.data()['title'])),
                        subtitle: Text(adminText(doc.data()['fileName'])),
                        trailing: const AdminBadge(
                          'AI failed',
                          color: Colors.orange,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminFileDetailsScreen(
                              fileId: doc.id,
                              catalog: catalog,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
