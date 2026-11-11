import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/admin_records.dart';
import '../../services/activity_log_service.dart';
import '../../services/admin_catalog.dart';
import 'admin_download.dart';
import 'admin_file_details_page.dart';
import 'admin_ui.dart';

class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({super.key});

  @override
  State<AdminActivityLogsScreen> createState() =>
      _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen> {
  static const _pageSize = 50;
  static const _categories = <String, String>{
    'all': 'All events',
    'login': 'Logins',
    'logout': 'Logouts',
    'course_created': 'Courses created',
    'material_uploaded': 'Files uploaded',
  };

  final _service = ActivityLogService();
  final _search = TextEditingController();
  final List<int?> _cursors = <int?>[null];
  String _category = 'all';
  String _period = '30 days';
  late Future<ActivityLogPage> _page;
  bool _isMigrating = false;
  String? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _page = _loadPage();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<ActivityLogPage> _loadPage() {
    final now = DateTime.now();
    final cutoff = switch (_period) {
      'Today' => DateTime(now.year, now.month, now.day),
      '7 days' => now.subtract(const Duration(days: 7)),
      '30 days' => now.subtract(const Duration(days: 30)),
      _ => null,
    };
    return _service.listAdmin(
      category: _category,
      since: cutoff,
      cursor: _cursors.last,
      limit: _pageSize,
    );
  }

  void _resetQuery() {
    _cursors
      ..clear()
      ..add(null);
    _page = _loadPage();
  }

  Future<void> _migrateHistory() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import existing activity history?'),
        content: const Text(
          'This securely copies legacy Firestore activity logs into Supabase. '
          'It is safe to run again and does not delete the original records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _isMigrating = true;
      _migrationStatus = 'Preparing import...';
    });
    try {
      final result = await _service.migrateLegacyLogs(
        onProgress: (copied, scanned) {
          if (!mounted) return;
          setState(() {
            _migrationStatus = 'Imported $copied of $scanned scanned logs';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isMigrating = false;
        _migrationStatus = null;
        _resetQuery();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Activity history imported: ${result.copied} valid logs '
            'from ${result.scanned} scanned records.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isMigrating = false;
        _migrationStatus = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  IconData _icon(String type) => switch (type) {
    'login' => Icons.login_rounded,
    'logout' => Icons.logout_rounded,
    'course_created' => Icons.library_add_outlined,
    _ => Icons.upload_file_outlined,
  };

  Future<void> _details(
    ActivityLogRecord document,
    AdminCatalog catalog,
  ) async {
    final row = document.data;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(adminEventLabels[adminText(row['type'])] ?? 'Activity'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: SelectableText(
              [
                'Recorded: ${adminTimestamp(row['createdAt'])}',
                if (row['occurredAt'] != null)
                  'Source created: ${adminTimestamp(row['occurredAt'])}',
                'Account: ${row['actorName']} (${row['actorRole']})',
                'Account UID: ${row['actorId']}',
                if (row['title'] != null) 'Title: ${row['title']}',
                if (row['courseId'] != null) 'Course ID: ${row['courseId']}',
                if (row['targetId'] != null) 'Source ID: ${row['targetId']}',
                'Event ID: ${document.id}',
              ].join('\n\n'),
            ),
          ),
        ),
        actions: [
          if (row['type'] == 'material_uploaded')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminFileDetailsScreen(
                      fileId: adminText(row['targetId']),
                      catalog: catalog,
                    ),
                  ),
                );
              },
              child: const Text('View file'),
            ),
          if (row['type'] == 'course_created')
            TextButton(
              onPressed: () async {
                try {
                  final source = await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(adminText(row['targetId']))
                      .get();
                  if (!dialogContext.mounted) return;
                  final course = source.data();
                  await showDialog<void>(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: Text(
                        course == null
                            ? 'Course unavailable'
                            : adminText(course['title']),
                      ),
                      content: SelectableText(
                        course == null
                            ? 'The course associated with this event is no longer available.'
                            : '${course['code']}\n${course['semester']} - ${course['academicYear']}\nInstructor: ${course['instructorName']}\nStatus: ${course['status']}\n\n${course['description']}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to load this course. Please retry.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('View course'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(List<ActivityLogRecord> rows) async {
    try {
      await downloadAdminCsv(
        adminCsv([
          [
            'Event ID',
            'Event',
            'Account',
            'Role',
            'Account UID',
            'Title',
            'Course ID',
            'Target ID',
            'Recorded',
            'Source created',
          ],
          ...rows.map((document) {
            final row = document.data;
            return [
              document.id,
              adminEventLabels[adminText(row['type'])] ?? row['type'],
              row['actorName'],
              row['actorRole'],
              row['actorId'],
              row['title'],
              row['courseId'],
              row['targetId'],
              adminTimestamp(row['createdAt']),
              row['occurredAt'] == null
                  ? ''
                  : adminTimestamp(row['occurredAt']),
            ];
          }),
        ]),
        'caslms-$_category-page-${_cursors.length}.csv',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to export this page. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AdminScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.resolve(context, AdminUi.background),
      body: FutureBuilder<ActivityLogPage>(
        future: _page,
        builder: (context, snapshot) {
          final page = snapshot.data?.rows ?? <ActivityLogRecord>[];
          final query = _search.text.trim().toLowerCase();
          final rows = page.where((document) {
            final row = document.data;
            return query.isEmpty ||
                [
                  document.id,
                  ...[
                    'actorName',
                    'actorId',
                    'actorRole',
                    'title',
                    'courseId',
                    'targetId',
                  ].map((field) => row[field]),
                ].any(
                  (value) => adminText(value).toLowerCase().contains(query),
                );
          }).toList();
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AdminPageHeading(
                title: 'Activity logs',
                subtitle: 'Separate account sessions, course creation and instructor uploads.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _isMigrating ? null : _migrateHistory,
                    icon: _isMigrating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_migrationStatus ?? 'Import Firestore history'),
                  ),
                  OutlinedButton.icon(
                    onPressed: waiting || snapshot.hasError || rows.isEmpty
                        ? null
                        : () => _export(rows),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export this page'),
                  ),
                  IconButton(
                    tooltip: 'Refresh logs',
                    onPressed: () => setState(() => _page = _loadPage()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _category == entry.key,
                        onSelected: (_) => setState(() {
                          _category = entry.key;
                          _resetQuery();
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              AdminPanel(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final search = TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search this page by account, role, course or event ID',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    );
                    final period = DropdownButtonFormField<String>(
                      initialValue: _period,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recorded during',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Today', '7 days', '30 days', 'All time']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _period = value!;
                        _resetQuery();
                      }),
                    );
                    return box.maxWidth < 700
                        ? Column(
                            children: [
                              period,
                              const SizedBox(height: 12),
                              search,
                            ],
                          )
                        : Row(
                            children: [
                              SizedBox(width: 185, child: period),
                              const SizedBox(width: 14),
                              Expanded(child: search),
                            ],
                          );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                AdminNotice(
                  'Unable to load activity logs. Check your connection and admin access, then retry.',
                  onRetry: () => setState(() => _page = _loadPage()),
                )
              else if (waiting)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AdminPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              '${_categories[_category]} - ${rows.length} shown',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.resolve(context, AdminUi.ink),
                              ),
                            ),
                            const AdminBadge('Supabase'),
                          ],
                        ),
                      ),
                      if (rows.isEmpty)
                        const AdminEmpty(
                          title: 'No matching events',
                          message: 'Try another category, period or page. Use Import Firestore history once to copy older activity records.',
                        )
                      else
                        ...rows.map((document) => _row(document, catalog)),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Page ${_cursors.length} - up to $_pageSize events',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.resolve(
                                  context,
                                  AdminUi.muted,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _cursors.length <= 1
                                  ? null
                                  : () => setState(() {
                                      _cursors.removeLast();
                                      _page = _loadPage();
                                    }),
                              child: const Text('Previous'),
                            ),
                            FilledButton(
                              onPressed: snapshot.data?.nextCursor == null
                                  ? null
                                  : () => setState(() {
                                      _cursors.add(snapshot.data!.nextCursor);
                                      _page = _loadPage();
                                    }),
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Logs record successful app sign-ins and explicit logout requests. Closing a browser does not log a logout. Export includes this page\'s visible matches; times use your browser\'s local timezone.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.resolve(context, AdminUi.muted),
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(ActivityLogRecord document, AdminCatalog catalog) {
    final row = document.data;
    final accent = AppColors.resolve(context, AdminUi.accent);
    final actor = adminText(row['actorName']).isEmpty
        ? adminText(row['actorId'])
        : adminText(row['actorName']);
    return InkWell(
      onTap: () => _details(document, catalog),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: .12),
              child: Icon(_icon(adminText(row['type'])), color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        actor,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      AdminBadge(
                        adminEventLabels[adminText(row['type'])] ??
                            adminText(row['type']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      adminText(row['actorRole']),
                      if (row['title'] != null) adminText(row['title']),
                    ].join(' - '),
                    style: TextStyle(
                      color: AppColors.resolve(context, AdminUi.muted),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    adminTimestamp(row['createdAt']),
                    style: TextStyle(
                      color: AppColors.resolve(context, AdminUi.muted),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
