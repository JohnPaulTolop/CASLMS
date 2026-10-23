import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/admin_records.dart';
import '../../services/admin_catalog.dart';
import 'admin_download.dart';
import 'admin_file_details_page.dart';
import 'admin_ui.dart';

class AdminFilesScreen extends StatefulWidget {
  const AdminFilesScreen({super.key});
  @override
  State<AdminFilesScreen> createState() => _AdminFilesScreenState();
}

class _AdminFilesScreenState extends State<AdminFilesScreen> {
  static const _pageSize = 40;
  final _search = TextEditingController();
  final List<DocumentSnapshot<Map<String, dynamic>>> _cursors = [];
  String? _course, _instructor;
  String _status = 'All';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

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
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('moduleResources')
        .where('deliveryType', isEqualTo: 'uploaded_file');
    if (_course != null) query = query.where('courseId', isEqualTo: _course);
    if (_instructor != null) {
      query = query.where('createdBy', isEqualTo: _instructor);
    }
    query = query
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (_cursors.isNotEmpty) query = query.startAfterDocument(_cursors.last);
    return query.limit(_pageSize + 1).snapshots();
  }

  void _refilter() {
    _cursors.clear();
    _stream = _query();
  }

  void _open(String id, AdminCatalog catalog) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AdminFileDetailsScreen(fileId: id, catalog: catalog),
    ),
  );

  Future<void> _export(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> files,
    AdminCatalog catalog,
  ) async {
    try {
      await downloadAdminCsv(
        adminCsv([
          [
            'File ID',
            'Title',
            'Filename',
            'Instructor',
            'Course',
            'Module ID',
            'Type',
            'Bytes',
            'Status',
            'Uploaded',
          ],
          ...files.map((doc) {
            final data = doc.data();
            final owner = catalog.users[adminText(data['createdBy'])];
            final course = catalog.courses[adminText(data['courseId'])];
            return [
              doc.id,
              data['title'],
              data['fileName'],
              owner?['name'] ?? data['createdBy'],
              course?['code'] ?? data['courseId'],
              data['moduleId'],
              adminFileType(data),
              data['sizeBytes'],
              data['status'],
              adminTimestamp(data['createdAt']),
            ];
          }),
        ]),
        'caslms-files-page-${_cursors.length + 1}.csv',
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
    final instructors =
        catalog.users.entries
            .where((entry) => entry.value['role'] == 'instructor')
            .toList()
          ..sort(
            (a, b) =>
                adminText(a.value['name'])
                    .compareTo(adminText(b.value['name'])),
          );
    final courses = catalog.courses.entries.toList()
      ..sort(
        (a, b) =>
            adminText(a.value['code']).compareTo(adminText(b.value['code'])),
      );
    return Scaffold(
      backgroundColor: AdminUi.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final raw = snapshot.data?.docs ?? [];
          final page = raw.take(_pageSize).toList();
          final query = _search.text.trim().toLowerCase();
          final files = page.where((doc) {
            final data = doc.data();
            return (_status == 'All' ||
                    adminText(data['status']) == _status.toLowerCase()) &&
                (query.isEmpty ||
                    [
                      data['title'],
                      data['fileName'],
                      data['moduleId'],
                      doc.id,
                      adminFileType(data),
                    ].any((v) => adminText(v).toLowerCase().contains(query)));
          }).toList();
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AdminPageHeading(
                title: 'Instructor files',
                subtitle: 'Browse uploaded learning materials by course and instructor.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: waiting || files.isEmpty || snapshot.hasError
                        ? null
                        : () => _export(files, catalog),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export this page'),
                  ),
                  IconButton(
                    tooltip: 'Refresh files',
                    onPressed: () => setState(() => _stream = _query()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (catalog.error != null) ...[
                AdminNotice(catalog.error!, onRetry: catalog.start),
                const SizedBox(height: 14),
              ],
              AdminPanel(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = box.maxWidth > 700
                        ? (box.maxWidth - 12) / 2
                        : box.maxWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'instructor-$_instructor-${instructors.length}',
                                ),
                                initialValue: _instructor ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Instructor · entire library',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('All instructors'),
                                  ),
                                  ...instructors.map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(
                                        adminText(e.value['name']),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (_instructor != null &&
                                      !instructors.any(
                                        (e) => e.key == _instructor,
                                      ))
                                    DropdownMenuItem(
                                      value: _instructor,
                                      child: const Text('Account unavailable'),
                                    ),
                                ],
                                onChanged: (v) => setState(() {
                                  _instructor = v == '' ? null : v;
                                  _refilter();
                                }),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'course-$_course-${courses.length}',
                                ),
                                initialValue: _course ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Course · entire library',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('All courses'),
                                  ),
                                  ...courses.map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(
                                        '${e.value['code']} · ${e.value['title']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (_course != null &&
                                      !courses.any((e) => e.key == _course))
                                    DropdownMenuItem(
                                      value: _course,
                                      child: const Text('Course unavailable'),
                                    ),
                                ],
                                onChanged: (v) => setState(() {
                                  _course = v == '' ? null : v;
                                  _refilter();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Search this page by filename, title, type or module ID',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () => setState(_search.clear),
                                    icon: const Icon(Icons.close),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ...['All', 'Published', 'Draft'].map(
                              (status) => ChoiceChip(
                                label: Text(
                                  status == 'All'
                                      ? 'All statuses on this page'
                                      : status,
                                ),
                                selected: _status == status,
                                onSelected: (_) =>
                                    setState(() => _status = status),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _course = null;
                                _instructor = null;
                                _status = 'All';
                                _search.clear();
                                _refilter();
                              }),
                              child: const Text('Reset filters'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                AdminNotice(
                  'Unable to load files. Check your connection and admin access, then retry.',
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
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${files.length} file${files.length == 1 ? '' : 's'} shown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AdminUi.ink,
                              ),
                            ),
                            const AdminBadge('Newest uploaded first'),
                            if (snapshot.data?.metadata.isFromCache == true)
                              const AdminBadge(
                                'Cached data',
                                color: Colors.orange,
                              ),
                          ],
                        ),
                      ),
                      if (files.isEmpty)
                        AdminEmpty(
                          title: page.isEmpty
                              ? 'No uploaded files here'
                              : 'No matches on this page',
                          message: page.isEmpty
                              ? 'Instructor uploads appear automatically. Try another course or instructor.'
                              : 'Change the search or status filter, or browse another page.',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, box) => box.maxWidth >= 850
                              ? _table(files, catalog)
                              : Column(
                                  children: files
                                      .map((doc) => _card(doc, catalog))
                                      .toList(),
                                ),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Page ${_cursors.length + 1} · up to $_pageSize records',
                              style: const TextStyle(
                                color: AdminUi.muted,
                                fontSize: 12,
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
                'Only uploaded learning materials are listed. Export includes the visible matches on this page. Times use your browser’s local timezone.',
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

  Widget _table(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> files,
    AdminCatalog catalog,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll(AdminUi.background),
      dataRowMinHeight: 68,
      dataRowMaxHeight: 78,
      columnSpacing: 22,
      columns: const [
        DataColumn(label: Text('Learning material')),
        DataColumn(label: Text('Instructor / course')),
        DataColumn(label: Text('Type / size')),
        DataColumn(label: Text('Uploaded')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('View')),
      ],
      rows: files.map((doc) {
        final file = doc.data();
        final course = catalog.courses[adminText(file['courseId'])];
        final owner = catalog.users[adminText(file['createdBy'])];
        return DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminText(file['title']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      adminText(file['fileName']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminUi.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => _open(doc.id, catalog),
            ),
            DataCell(
              SizedBox(
                width: 170,
                child: Text(
                  '${owner?['name'] ?? 'Account unavailable'}\n${course?['code'] ?? 'Course unavailable'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(
              Text(
                '${adminFileType(file)}\n${adminFileSize(file['sizeBytes'])}',
              ),
            ),
            DataCell(Text(adminTimestamp(file['createdAt']))),
            DataCell(
              AdminBadge(
                adminText(file['status']),
                color: file['status'] == 'published'
                    ? Colors.teal
                    : Colors.orange,
              ),
            ),
            DataCell(
              IconButton(
                tooltip: 'View learning material',
                onPressed: () => _open(doc.id, catalog),
                icon: const Icon(Icons.visibility_outlined),
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );

  Widget _card(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    AdminCatalog catalog,
  ) {
    final file = doc.data();
    final course = catalog.courses[adminText(file['courseId'])];
    final owner = catalog.users[adminText(file['createdBy'])];
    return InkWell(
      onTap: () => _open(doc.id, catalog),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.insert_drive_file_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adminText(file['title']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    adminText(file['fileName']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AdminUi.muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      owner?['name'] ?? 'Account unavailable',
                      course?['code'] ?? 'Course unavailable',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AdminUi.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AdminBadge(adminFileType(file)),
                      AdminBadge(adminFileSize(file['sizeBytes'])),
                      AdminBadge(adminText(file['status'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    adminTimestamp(file['createdAt']),
                    style: const TextStyle(fontSize: 11, color: AdminUi.muted),
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
