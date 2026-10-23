import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';
import '../../models/admin_records.dart';
import '../../services/admin_catalog.dart';
import 'admin_document_frame.dart';
import 'admin_ui.dart';

class AdminFileDetailsScreen extends StatefulWidget {
  const AdminFileDetailsScreen({
    super.key,
    required this.fileId,
    required this.catalog,
  });
  final String fileId;
  final AdminCatalog catalog;
  @override
  State<AdminFileDetailsScreen> createState() => _AdminFileDetailsScreenState();
}

class _AdminFileDetailsScreenState extends State<AdminFileDetailsScreen> {
  late final _stream = FirebaseFirestore.instance
      .collection('moduleResources')
      .doc(widget.fileId)
      .snapshots();
  String? _moduleName;
  String? _loadedModule;

  Future<void> _loadModule(String id) async {
    if (_loadedModule == id) return;
    _loadedModule = id;
    if (id.isEmpty) {
      _moduleName = 'Not recorded';
      return;
    }
    try {
      final data = id.isEmpty
          ? null
          : (await FirebaseFirestore.instance
                    .collection('modules')
                    .doc(id)
                    .get())
                .data();
      if (mounted && _loadedModule == id) {
        setState(
          () => _moduleName = adminText(data?['title']).isEmpty
              ? 'Module no longer available'
              : adminText(data?['title']),
        );
      }
    } catch (_) {
      if (mounted && _loadedModule == id) {
        setState(() => _moduleName = 'Module details unavailable');
      }
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw StateError('Unable to open file');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open this file. Check whether it still exists.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminAccessGuard(
    child: ListenableBuilder(
      listenable: widget.catalog,
      builder: (context, child) => Scaffold(
        backgroundColor: AdminUi.background,
        appBar: AppBar(
          title: const Text('Learning material'),
          backgroundColor: Colors.white,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AdminEmpty(
                title: 'Unable to load file',
                message: 'Check your connection and administrator access.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final file = snapshot.data!.data();
            if (file == null) {
              return const AdminEmpty(
                title: 'File record unavailable',
                message: 'This learning material may have been removed.',
              );
            }
            final uri = adminMaterialUri(
              file,
              SupabaseConfig.projectUrl,
              SupabaseConfig.learningMaterialsBucket,
            );
            final type = adminFileType(file);
            final catalog = widget.catalog;
            final course = catalog.courses[adminText(file['courseId'])];
            final owner = catalog.users[adminText(file['createdBy'])];
            _loadModule(adminText(file['moduleId']));
            final name = adminText(file['fileName']).isEmpty
                ? adminText(file['title'])
                : adminText(file['fileName']);
            Widget metadata() => AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adminText(file['title']),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AdminUi.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    name,
                    style: const TextStyle(color: AdminUi.muted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AdminBadge(type),
                      AdminBadge(adminText(file['status'])),
                      AdminBadge(adminFileSize(file['sizeBytes'])),
                    ],
                  ),
                  const Divider(height: 30),
                  _detail(
                    'Instructor',
                    owner?['name'] ??
                        'Account unavailable (${adminText(file['createdBy'])})',
                  ),
                  _detail(
                    'Course',
                    course == null
                        ? 'Course unavailable (${adminText(file['courseId'])})'
                        : '${course['code']} · ${course['title']}',
                  ),
                  _detail('Module', _moduleName ?? 'Loading module…'),
                  _detail('Uploaded', adminTimestamp(file['createdAt'])),
                  _detail('Last updated', adminTimestamp(file['updatedAt'])),
                  _detail(
                    'AI processing',
                    adminText(file['aiProcessingStatus']).isEmpty
                        ? 'Not requested'
                        : file['aiProcessingStatus'],
                  ),
                  if (adminText(file['description']).isNotEmpty) ...[
                    const Divider(height: 28),
                    SelectableText(adminText(file['description'])),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: uri == null ? null : () => _open(uri),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open original / save file'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'PDFs and images can be previewed here. Office documents, archives and other files open in their original application.',
                    style: TextStyle(
                      color: AdminUi.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
            Widget preview() {
              if (uri == null) {
                return const AdminEmpty(
                  title: 'Preview unavailable',
                  message: 'This record does not have a valid learning-material storage URL.',
                );
              }
              if (['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP'].contains(type)) {
                return InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: Image.network(
                    uri.toString(),
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stack) => const AdminEmpty(
                      title: 'Image unavailable',
                      message: 'The stored object may have been removed.',
                    ),
                  ),
                );
              }
              if (type == 'PDF') return AdminDocumentFrame(uri: uri);
              return AdminEmpty(
                title: '$type document',
                message:
                    'Choose Open original / save file to view this format.',
                icon: Icons.description_outlined,
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 1000;
                final previewPanel = AdminPanel(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(height: wide ? 650 : 480, child: preview()),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 350, child: metadata()),
                            const SizedBox(width: 20),
                            Expanded(child: previewPanel),
                          ],
                        )
                      : Column(
                          children: [
                            metadata(),
                            const SizedBox(height: 20),
                            previewPanel,
                          ],
                        ),
                );
              },
            );
          },
        ),
      ),
    ),
  );

  Widget _detail(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AdminUi.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          adminText(value),
          style: const TextStyle(color: AdminUi.ink, height: 1.4),
        ),
      ],
    ),
  );
}
