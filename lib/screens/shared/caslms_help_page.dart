import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaslmsGuide {
  const CaslmsGuide(this.title, this.steps, {this.planned = false});

  final String title;
  final List<String> steps;
  final bool planned;
}

class CaslmsGuides {
  static List<CaslmsGuide> forRole(String role) {
    if (role == 'instructor') {
      return const [
        CaslmsGuide('Create a course', [
          'Open My Courses from the instructor dashboard.',
          'Select Create Course.',
          'Enter the course code, title, description, and academic details.',
          'Save the course, then open its details.',
        ]),
        CaslmsGuide('Add a section', [
          'Open My Courses and choose a course.',
          'Select Add Section.',
          'Enter a section name and identifier, such as BSIT 1A.',
          'Save. Each new section receives its own class code.',
          'Add as many sections as needed; there is no fixed limit.',
        ]),
        CaslmsGuide('Enroll students', [
          'Open the course and identify the correct section.',
          'For new sections, share the section-specific class code.',
          'Students use Join Section with Code.',
          'For original classes, use the instructor invitation workflow.',
          'Check the student roster before assigning activities.',
        ]),
        CaslmsGuide('Upload learning materials', [
          'Open the course and select Course Tools & Materials.',
          'Open or create the appropriate module.',
          'Choose the option for adding learning materials.',
          'Select a supported file or link, then save.',
          'Verify that students can access the published material.',
        ]),
        CaslmsGuide('Create assessments', [
          'Open the relevant course and module.',
          'Choose Create Assessment.',
          'Select the assessment type and enter instructions.',
          'Set points, submission details, and the due date.',
          'Review the assessment before publishing.',
          'Section-specific assessment controls are being integrated.',
        ]),
        CaslmsGuide('Use the AI assistant', [
          'Open the AI Assistant tab in the instructor area.',
          'Choose a course context if the teaching assistant is available.',
          'Ask for lesson plans, quizzes, assignments, or learning activities.',
          'Review the result before copying it into your materials.',
          'AI requires a working Firebase AI service and available quota.',
        ]),
        CaslmsGuide('Create grading rubrics', [
          'Choose the essay assessment you want to grade.',
          'Define criteria such as content, organization, and grammar.',
          'Assign maximum points or weights to each criterion.',
          'Review the rubric before it is used for grading.',
          'The rubric editor is part of the ongoing essay-grading feature.',
        ], planned: true),
        CaslmsGuide('Check student submissions', [
          'Open the instructor Grading area.',
          'Select the course and assessment.',
          'Review each available student submission.',
          'Check the response, attachments, and submission status.',
          'Section-specific submission separation is being integrated.',
        ]),
        CaslmsGuide('Review and publish grades', [
          'Open an assessment submission in Grading.',
          'Review the score and instructor feedback.',
          'For AI-assisted essays, treat any AI score as a suggestion.',
          'Correct the score and feedback before approving.',
          'The full AI rubric approval workflow is still being developed.',
        ], planned: true),
      ];
    }

    if (role == 'student') {
      return const [
        CaslmsGuide('Join a section', [
          'Open the Student Dashboard.',
          'Select Join Section with Code.',
          'Enter the code provided by your instructor.',
          'For an original class, check Course Invitations instead.',
        ]),
        CaslmsGuide('Find learning materials', [
          'Open your enrolled classes.',
          'Choose the course and look for its modules.',
          'Open a module to view available learning materials.',
        ]),
        CaslmsGuide('Complete assessments', [
          'Open Assignments or the assessment inside a course.',
          'Read the instructions and due date.',
          'Complete the activity and verify successful submission.',
        ]),
        CaslmsGuide('View grades and feedback', [
          'Open your Progress or assessment results area.',
          'Review published results and instructor feedback.',
          'Contact your instructor about missing or incorrect results.',
        ]),
      ];
    }

    return const [
      CaslmsGuide('Get started', [
        'Review the main dashboard.',
        'Use the navigation menu to open your assigned features.',
        'Check notifications for new actions or updates.',
      ]),
      CaslmsGuide('Use the system safely', [
        'Only access records you are authorized to view.',
        'Review information before saving important changes.',
        'Sign out after using a shared computer.',
      ]),
      CaslmsGuide('Find help', [
        'Open Help & User Guide.',
        'Choose a topic that matches your task.',
        'Replay the guided tour whenever you need a refresher.',
      ]),
    ];
  }
}

class CaslmsOnboarding {
  static String _key(String role, String uid) =>
      'caslms_onboarding_v1_${role}_$uid';

  static Future<void> maybeShow(
    BuildContext context, {
    required String role,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = SharedPreferencesAsync();
    final key = _key(role, uid);

    bool completed;
    try {
      completed = await prefs.getBool(key) ?? false;
    } catch (_) {
      // Local storage may be disabled in a private browser session.
      return;
    }

    if (completed || !context.mounted) return;

    final dismissed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CaslmsTourDialog(role: role),
    );

    if (dismissed == true) {
      try {
        await prefs.setBool(key, true);
      } catch (_) {
        // No Firestore fallback: onboarding remains optional.
      }
    }
  }

  static Future<void> replay(
    BuildContext context, {
    required String role,
  }) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CaslmsTourDialog(role: role),
    );
  }
}

class _CaslmsTourDialog extends StatefulWidget {
  const _CaslmsTourDialog({required this.role});

  final String role;

  @override
  State<_CaslmsTourDialog> createState() => _CaslmsTourDialogState();
}

class _CaslmsTourDialogState extends State<_CaslmsTourDialog> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final entries = CaslmsGuides.forRole(widget.role);
    final entry = entries[index];
    final last = index == entries.length - 1;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.school_outlined, color: Color(0xFF00897B)),
          SizedBox(width: 10),
          Expanded(child: Text('Welcome to CASLMS')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (index + 1) / entries.length,
              color: const Color(0xFF00897B),
            ),
            const SizedBox(height: 16),
            Text(
              '${index + 1} of ${entries.length}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...entry.steps
                .take(3)
                .map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $step'),
                  ),
                ),
            if (entry.planned)
              const Text(
                'This feature is still being developed.',
                style: TextStyle(color: Colors.deepOrange),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Skip tour'),
        ),
        if (index > 0)
          TextButton(
            onPressed: () => setState(() => index--),
            child: const Text('Back'),
          ),
        FilledButton(
          onPressed: () {
            if (last) {
              Navigator.pop(context, true);
            } else {
              setState(() => index++);
            }
          },
          child: Text(last ? 'Finish' : 'Next'),
        ),
      ],
    );
  }
}

class CaslmsHelpPage extends StatefulWidget {
  const CaslmsHelpPage({super.key, required this.role});

  final String role;

  @override
  State<CaslmsHelpPage> createState() => _CaslmsHelpPageState();
}

class _CaslmsHelpPageState extends State<CaslmsHelpPage> {
  final search = TextEditingController();
  String filter = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = CaslmsGuides.forRole(widget.role)
        .where(
          (entry) =>
              entry.title.toLowerCase().contains(filter) ||
              entry.steps.any((step) => step.toLowerCase().contains(filter)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & User Guide'),
        actions: [
          IconButton(
            tooltip: 'Replay the beginner guided tour',
            onPressed: () =>
                CaslmsOnboarding.replay(context, role: widget.role),
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'CASLMS Beginner Guide',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a task to see simple step-by-step instructions. '
                'Topics marked In development describe planned workflows.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: search,
                onChanged: (value) =>
                    setState(() => filter = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search help topics...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No matching guide topics.'),
                ),
              ...entries.map(
                (entry) => Card(
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: Color(0xFF00897B),
                    ),
                    title: Text(entry.title),
                    subtitle: entry.planned
                        ? const Text(
                            'In development',
                            style: TextStyle(color: Colors.deepOrange),
                          )
                        : null,
                    children: [
                      for (var i = 0; i < entry.steps.length; i++)
                        ListTile(
                          leading: CircleAvatar(
                            radius: 13,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(entry.steps[i]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    CaslmsOnboarding.replay(context, role: widget.role),
                icon: const Icon(Icons.replay),
                label: const Text('Replay guided tour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
