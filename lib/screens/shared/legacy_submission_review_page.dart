import 'package:flutter/material.dart';

import '../../services/assignment_service.dart';

/// Review an exact legacy submission, using the existing grading service.
class LegacySubmissionReviewScreen extends StatefulWidget {
  const LegacySubmissionReviewScreen({super.key, required this.submission});
  final Map<String, dynamic> submission;
  @override
  State<LegacySubmissionReviewScreen> createState() =>
      _LegacySubmissionReviewScreenState();
}

class _LegacySubmissionReviewScreenState
    extends State<LegacySubmissionReviewScreen> {
  late final _score = TextEditingController(
    text: widget.submission['score']?.toString() ?? '',
  );
  late final _feedback = TextEditingController(
    text: (widget.submission['feedback'] ?? '').toString(),
  );
  bool _busy = false;
  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final score = int.tryParse(_score.text.trim());
    if (score == null || score < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid non-negative whole-number score.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AssignmentService().gradeSubmission(
        submissionId: widget.submission['id'].toString(),
        score: score,
        feedback: _feedback.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Grade saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review submission')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SelectableText(
          'Student: ${widget.submission['studentName'] ?? widget.submission['studentId']}',
        ),
        const SizedBox(height: 16),
        SelectableText((widget.submission['answerText'] ?? '').toString()),
        const SizedBox(height: 16),
        SelectableText((widget.submission['fileUrl'] ?? '').toString()),
        const SizedBox(height: 16),
        TextField(
          controller: _score,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Points earned'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _feedback,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Feedback'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save grade'),
        ),
      ],
    ),
  );
}
