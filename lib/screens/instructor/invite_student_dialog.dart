import 'package:flutter/material.dart';

import '../../services/course_invitation_service.dart';
import '../../services/course_section_service.dart';

class InviteStudentDialog extends StatefulWidget {
  const InviteStudentDialog({
    super.key,
    required this.courseId,
    this.sectionId,
  });
  final String courseId;
  final String? sectionId;

  @override
  State<InviteStudentDialog> createState() => _InviteStudentDialogState();
}

class _InviteStudentDialogState extends State<InviteStudentDialog> {
  final _campusId = TextEditingController();
  final _form = GlobalKey<FormState>();
  late Future<List<Map<String, dynamic>>> _sections;
  String? _sectionId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sectionId = widget.sectionId;
    _sections = CourseSectionService().getSections(widget.courseId);
  }

  @override
  void dispose() {
    _campusId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _form.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CourseInvitationService().inviteStudentByCampusId(
        courseId: widget.courseId,
        campusId: _campusId.text,
        sectionId: _sectionId,
      );
      if (mounted) Navigator.pop(context, true);
    } on CourseInvitationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to send invitation. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Invite student to section'),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _sections,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load sections.'),
                    TextButton(
                      onPressed: () => setState(
                        () => _sections = CourseSectionService().getSections(
                          widget.courseId,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final sections = snapshot.data!
                  .where((s) => s['status'] == 'active')
                  .toList();
              final validSelection = sections.any(
                (s) => s['id'] == _sectionId || s['sectionId'] == _sectionId,
              );
              return SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Use the Campus ID registered to the student’s CASLMS account. They will receive an invitation to the selected section.',
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: validSelection ? _sectionId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: sections
                            .map(
                              (s) => DropdownMenuItem(
                                value: (s['sectionId'] ?? s['id']).toString(),
                                child: Text(
                                  (s['name'] ?? 'Section').toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy || widget.sectionId != null
                            ? null
                            : (value) => setState(() => _sectionId = value),
                        validator: (value) =>
                            value == null ? 'Select an active section.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _campusId,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Student Campus ID',
                          hintText: '5–12 digits',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) =>
                            RegExp(r'^\d{5,12}$').hasMatch(
                              (value ?? '').replaceAll(RegExp(r'\s+'), ''),
                            )
                            ? null
                            : 'Enter a valid Campus ID (5–12 digits).',
                        onFieldSubmitted: (_) => _send(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enrollment becomes active when the student accepts. Students in another section must be transferred instead.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF68738A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Sending…' : 'Send invitation'),
          ),
        ],
      ),
    );
  }
}
