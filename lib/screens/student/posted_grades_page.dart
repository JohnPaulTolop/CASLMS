import 'package:flutter/material.dart';

import '../../models/gradebook_models.dart';
import '../../services/semester_grades_service.dart';

class PostedGradesScreen extends StatefulWidget {
  const PostedGradesScreen({super.key, this.api});
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
    _load();
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
    backgroundColor: const Color(0xFFF7F9FC),
    appBar: AppBar(
      title: const Text('Posted Grades'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: 'Refresh and hide grades',
          onPressed: _loading ? null : () => _load(_termId),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your semester grades',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grades stay hidden until you verify your Student ID and password. Refreshing or leaving the browser hides revealed grades.',
          ),
          const SizedBox(height: 18),
          if (_terms.isNotEmpty)
            SizedBox(
              width: 380,
              child: DropdownButtonFormField<String>(
                key: ValueKey(_termId),
                initialValue: _termId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Academic year / semester',
                  border: OutlineInputBorder(),
                ),
                items: _terms
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text(row['label'] as String),
                      ),
                    )
                    .toList(),
                onChanged: _loading ? null : (value) => _load(value),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _subjects.isEmpty
                ? const Center(
                    child: Text('No enrolled subjects for this semester.'),
                  )
                : ListView.separated(
                    itemCount: _subjects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final subject = _subjects[index];
                      final grade = _revealed[subject.courseId];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 14,
                            spacing: 24,
                            children: [
                              SizedBox(
                                width: 300,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(subject.title),
                                    const SizedBox(height: 12),
                                    if (grade == null)
                                      const Text(
                                        'Grade: [ Hidden ]',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Grade: ${grade.grade} · ${grade.result}${grade.description.isEmpty || grade.description == grade.result ? '' : ' · ${grade.description}'}',
                                        key: ValueKey(
                                          'revealed-${subject.courseId}',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!subject.posted)
                                const Chip(label: Text('Not posted yet'))
                              else if (grade == null)
                                FilledButton.icon(
                                  key: ValueKey('reveal-${subject.courseId}'),
                                  onPressed: () => _reveal(subject),
                                  icon: const Icon(Icons.lock_outline),
                                  label: const Text('Reveal Grade'),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                    () => _revealed.remove(subject.courseId),
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                  ),
                                  label: const Text('Hide Grade'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
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
    title: const Text('Reveal your grade'),
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Account Password',
                border: OutlineInputBorder(),
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
