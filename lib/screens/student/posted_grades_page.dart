import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'package:flutter/material.dart';

import '../../models/gradebook_models.dart';
import '../../services/semester_grades_service.dart';
import '../shared/grading_ui.dart';

class PostedGradesScreen extends StatefulWidget {
  const PostedGradesScreen({
    super.key,
    this.api,
    this.initialCourseId = '',
    this.initialTermId = '',
  });
  final String initialCourseId, initialTermId;
  final GradebookApi? api;
  @override
  State<PostedGradesScreen> createState() => _PostedGradesScreenState();
}

class _PostedGradesScreenState extends State<PostedGradesScreen>
    with WidgetsBindingObserver {
  late final GradebookApi _api = widget.api ?? SemesterGradesService();
  final Map<String, RevealedGrade> _revealed = {};
  List<PostedSubject> _subjects = [];
  List<Map<String, dynamic>> _terms = [];
  String? _termId, _error;
  bool _loading = true;
  bool _visible = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(widget.initialTermId.isEmpty ? null : widget.initialTermId);
  }

  @override
  void dispose() {
    _revealed.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (!_visible && mounted) {
      setState(_revealed.clear);
    }
  }

  Future<void> _load([String? selected]) async {
    setState(() {
      _revealed.clear();
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.request('posted', {'termId': ?selected});
      if (!mounted) return;
      setState(() {
        _subjects = (result['subjects'] as List)
            .map(
              (row) =>
                  PostedSubject.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        _terms = (result['terms'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _termId = result['termId'] as String;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _reveal(PostedSubject subject) async {
    final grade = await showDialog<RevealedGrade>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RevealDialog(api: _api, subject: subject),
    );
    if (grade != null && mounted && _visible) {
      setState(() => _revealed[subject.courseId] = grade);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.resolve(context, gradeBackground),
    body: RefreshIndicator(
      onRefresh: () => _load(_termId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          workspaceInset(MediaQuery.sizeOf(context).width),
          0,
          workspaceInset(MediaQuery.sizeOf(context).width),
          32,
        ),
        children: [
          WorkspaceHeading(
            showEyebrow: false,
            inlineActions: true,
            title: 'Posted grades',
            subtitle:
                'Choose a semester, then securely reveal your posted grades.',
            eyebrow: 'YOUR SEMESTER',
            actions: [
              if (_revealed.isNotEmpty)
                RoundGradeAction(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide all grades',
                  accent: gradeBlue,
                  onTap: () => setState(_revealed.clear),
                ),
              RoundGradeAction(
                icon: Icons.refresh_rounded,
                label: 'Refresh and hide grades',
                accent: gradeBlue,
                onTap: _loading ? null : () => _load(_termId),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const GradeEntrance(
            child: GradeHero(
              title: 'Your grades, kept private.',
              subtitle: 'Choose a semester, then verify your Student ID and password to reveal a posted grade. Refreshing or leaving the browser hides revealed grades.',
              icon: Icons.lock_person_outlined,
              eyebrow: 'YOUR SEMESTER',
            ),
          ),
          const SizedBox(height: 16),
          if (!_loading && _error == null) ...[
            GradeStats(
              items: [
                (
                  label: 'Enrolled subjects',
                  value: '${_subjects.length}',
                  icon: Icons.menu_book_outlined,
                  color: AppColors.resolve(context, gradeBlue),
                ),
                (
                  label: 'Grades posted',
                  value:
                      '${_subjects.where((subject) => subject.posted).length}',
                  icon: Icons.verified_outlined,
                  color: AppColors.resolve(context, gradeTeal),
                ),
                (
                  label: 'Grades hidden',
                  value: '${_subjects.length - _revealed.length}',
                  icon: Icons.lock_outline,
                  color: const Color(0xFF8660C7),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (_terms.isNotEmpty)
            GradeSurface(
              child: DropdownButtonFormField<String>(
                key: ValueKey(_termId),
                initialValue: _termId,
                isExpanded: true,
                decoration: gradeInput(
                  'Academic year / semester',
                  icon: Icons.calendar_month_outlined,
                ),
                items: _terms
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text(
                          row['label'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading ? null : (value) => _load(value),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Your subjects',
            style: TextStyle(
              color: AppColors.resolve(context, gradeInk),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const GradeSurface(
              child: WorkspaceLoadingState(label: 'Loading posted grades…'),
            )
          else if (_error != null)
            GradeStateMessage(
              title: 'Could not load grades',
              message: _error!,
              icon: Icons.cloud_off_outlined,
              onRetry: () => _load(_termId),
            )
          else if (_subjects.isEmpty)
            const GradeStateMessage(
              title: 'No subjects yet',
              message: 'No enrolled subjects for this semester.',
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns =
                    box.maxWidth >= 840 &&
                        MediaQuery.textScalerOf(context).scale(14) < 23
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  children: [
                    for (final subject in _subjects.where(
                      (subject) =>
                          widget.initialCourseId.isEmpty ||
                          subject.courseId == widget.initialCourseId,
                    ))
                      SizedBox(
                        width: (box.maxWidth - (columns - 1) * 16) / columns,
                        child: _subjectCard(subject),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
  Widget _subjectCard(PostedSubject subject) {
    final grade = _revealed[subject.courseId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GradeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.resolve(
                    context,
                    AppColors.blueTint,
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.resolve(context, gradeBlue),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.code,
                        style: TextStyle(
                          color: AppColors.resolve(context, gradeInk),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject.title,
                        style: TextStyle(
                          color: AppColors.resolve(context, gradeMuted),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: gradeMotion(context),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: grade == null
                    ? AppColors.resolve(context, AppColors.background)
                    : gradeTeal.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: grade == null
                      ? AppColors.resolve(context, gradeBorder)
                      : gradeTeal.withValues(alpha: .2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replace sensitive text immediately; no outgoing animation may retain a grade.
                  if (grade == null)
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.resolve(context, gradeMuted),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Grade: [ Hidden ]',
                            style: TextStyle(
                              color: AppColors.resolve(context, gradeMuted),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    GradeEntrance(
                      key: ValueKey('grade-entrance-${subject.courseId}'),
                      child: Text(
                        'Grade: ${grade.grade} · ${grade.result}${grade.description.isEmpty || grade.description == grade.result ? '' : ' · ${grade.description}'}',
                        key: ValueKey('revealed-${subject.courseId}'),
                        style: TextStyle(
                          color: AppColors.resolve(context, gradeTeal),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    grade != null
                        ? 'Visible until you hide it, refresh, or leave the browser.'
                        : subject.posted
                        ? 'Your instructor has posted this grade. Verify to view it.'
                        : 'Your instructor has not posted a final grade yet.',
                    style: TextStyle(
                      color: AppColors.resolve(context, gradeMuted),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: !subject.posted
                  ? GradeBadge(
                      'Not posted yet',
                      color: AppColors.resolve(context, gradeMuted),
                      icon: Icons.schedule_outlined,
                    )
                  : grade == null
                  ? FilledButton.icon(
                      key: ValueKey('reveal-${subject.courseId}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.resolve(context, gradeBlue),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () => _reveal(subject),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Reveal Grade'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _revealed.remove(subject.courseId)),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('Hide Grade'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealDialog extends StatefulWidget {
  const _RevealDialog({required this.api, required this.subject});
  final GradebookApi api;
  final PostedSubject subject;
  @override
  State<_RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<_RevealDialog> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _id.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_id.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your Student ID and account password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.request('reveal', {
        'courseId': widget.subject.courseId,
        'termId': widget.subject.termId,
        'campusId': _id.text.trim(),
        'password': _password.text,
      });
      _password.clear();
      if (mounted) Navigator.of(context).pop(RevealedGrade.fromJson(result));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: AppColors.resolve(context, Colors.white),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.resolve(context, AppColors.blueTint),
          child: Icon(
            Icons.lock_person_outlined,
            color: AppColors.resolve(context, gradeBlue),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Reveal your grade',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
    content: SizedBox(
      width: 390,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.subject.code} · ${widget.subject.title}'),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('reveal-student-id'),
              controller: _id,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              decoration: gradeInput('Student ID', icon: Icons.badge_outlined),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('reveal-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(),
              decoration: gradeInput(
                'Account Password',
                icon: Icons.lock_outline,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Verifying...' : 'Verify & Reveal'),
      ),
    ],
  );
}
