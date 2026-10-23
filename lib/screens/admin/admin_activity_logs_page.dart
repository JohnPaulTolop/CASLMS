import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/admin_records.dart';
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
  final _search = TextEditingController();
  final List<DocumentSnapshot<Map<String, dynamic>>> _cursors = [];
  String _category = 'all', _period = '30 days';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  static const _categories = {
    'all': 'All events',
    'login': 'Logins',
    'logout': 'Logouts',
    'course_created': 'Courses created',
    'material_uploaded': 'Files uploaded',
  };

  @override
  void initState() {
    super.initState();
    _stream = _query();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'activityLogs',
    );
    if (_category != 'all') query = query.where('type', isEqualTo: _category);
    final now = DateTime.now();
    final cutoff = switch (_period) {
      'Today' => DateTime(now.year, now.month, now.day),
      '7 days' => now.subtract(const Duration(days: 7)),
      '30 days' => now.subtract(const Duration(days: 30)),
      _ => null,
    };
    if (cutoff != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
      );
    }
    query = query
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (_cursors.isNotEmpty) query = query.startAfterDocument(_cursors.last);
    return query.limit(_pageSize + 1).snapshots();
  }

  void _resetQuery() {
    _cursors.clear();
    _stream = _query();
  }

  IconData _icon(String type) => switch (type) {
    'login' => Icons.login_rounded,
    'logout' => Icons.logout_rounded,
    'course_created' => Icons.library_add_outlined,
    _ => Icons.upload_file_outlined,
  };

  Future<void> _details(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    AdminCatalog catalog,
  ) async {
    final row = doc.data();
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
                'Event ID: ${doc.id}',
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
                            : '${course['code']}\n${course['semester']} · ${course['academicYear']}\nInstructor: ${course['instructorName']}\nStatus: ${course['status']}\n\n${course['description']}',
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

  Future<void> _export(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rows,
  ) async {
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
          ...rows.map((doc) {
            final row = doc.data();
            return [
              doc.id,
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
        'caslms-$_category-page-${_cursors.length + 1}.csv',
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
      backgroundColor: AdminUi.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final raw = snapshot.data?.docs ?? [];
          final page = raw.take(_pageSize).toList();
          final query = _search.text.trim().toLowerCase();
          final rows = page
              .where(
                (doc) =>
                    query.isEmpty ||
                    [
                      doc.id,
                      ...[
                        'actorName',
                        'actorId',
                        'actorRole',
                        'title',
                        'courseId',
                        'targetId',
                      ].map((field) => doc.data()[field]),
                    ].any((v) => adminText(v).toLowerCase().contains(query)),
              )
              .toList();
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AdminPageHeading(
                title: 'Activity logs',
                subtitle: 'Separate account sessions, course creation and instructor uploads.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: waiting || snapshot.hasError || rows.isEmpty
                        ? null
                        : () => _export(rows),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export this page'),
                  ),
                  IconButton(
                    tooltip: 'Refresh logs',
                    onPressed: () => setState(() => _stream = _query()),
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
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
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
                  onRetry: () => setState(() => _stream = _query()),
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
                              '${_categories[_category]} · ${rows.length} shown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminUi.ink,
                              ),
                            ),
                            const AdminBadge('Live updates'),
                            if (snapshot.data?.metadata.isFromCache == true)
                              const AdminBadge(
                                'Cached data',
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ),
                      if (rows.isEmpty)
                        const AdminEmpty(
                          title: 'No matching events',
                          message: 'Activity history begins with this update. Try another category, period or page. Older course records remain available under Courses.',
                        )
                      else
                        ...rows.map((doc) => _row(doc, catalog)),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Page ${_cursors.length + 1} · up to $_pageSize events',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminUi.muted,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _cursors.isEmpty
                                  ? null
                                  : () => setState(() {
                                      _cursors.removeLast();
                                      _stream = _query();
                                    }),
                              child: const Text('Previous'),
                            ),
                            FilledButton(
                              onPressed: raw.length <= _pageSize
                                  ? null
                                  : () => setState(() {
                                      _cursors.add(page.last);
                                      _stream = _query();
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
              const Text(
                'Logs record successful app sign-ins and explicit logout requests. Closing a browser does not log a logout. Export includes this page’s visible matches; times use your browser’s local timezone.',
                style: TextStyle(
                  fontSize: 12,
                  color: AdminUi.muted,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    AdminCatalog catalog,
  ) {
    final row = doc.data();
    final actor = adminText(row['actorName']).isEmpty
        ? adminText(row['actorId'])
        : adminText(row['actorName']);
    return InkWell(
      onTap: () => _details(doc, catalog),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AdminUi.accent.withValues(alpha: .08),
              child: Icon(_icon(adminText(row['type'])), color: AdminUi.accent),
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
                    ].join(' · '),
                    style: const TextStyle(color: AdminUi.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    adminTimestamp(row['createdAt']),
                    style: const TextStyle(color: AdminUi.muted, fontSize: 11),
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
