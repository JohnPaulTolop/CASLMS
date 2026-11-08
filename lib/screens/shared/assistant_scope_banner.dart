import 'package:flutter/material.dart';

/// Shared topic guidance for every role's chat assistant.
class AssistantScopeBanner extends StatelessWidget {
  const AssistantScopeBanner({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .06),
      border: Border.all(color: color.withValues(alpha: .18)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.school_outlined, color: color, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LMS, academics & education technology',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                'Courses, grades, modules, assignments and platform help.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'What can I ask?',
          icon: Icon(Icons.info_outline_rounded, color: color, size: 21),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('What can I ask?'),
              content: const SingleChildScrollView(
                child: Text(
                  'Ask about classes, invitations, submissions, learning materials, '
                  'grade navigation, account settings and other CAS LMS tasks.\n\n'
                  'Academic help must connect to a course, assignment, study task, '
                  'or teaching responsibility. Education-technology questions are '
                  'also supported.\n\n'
                  'Use the records view for permitted personal record lookups. '
                  'Study Help cannot look up private grades or account records.\n\n'
                  'Unrelated coding projects, creative stories, medical or legal '
                  'advice, shopping, entertainment, and general trivia are outside '
                  "this assistant's scope.\n\n"
                  'Never share passwords, API keys or other private credentials.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
