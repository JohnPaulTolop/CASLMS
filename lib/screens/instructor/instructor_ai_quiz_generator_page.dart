import 'package:flutter/material.dart';

import 'instructor_ui.dart';

class InstructorAIQuizGeneratorScreen extends StatefulWidget {
  const InstructorAIQuizGeneratorScreen({super.key});

  @override
  State<InstructorAIQuizGeneratorScreen> createState() =>
      _InstructorAIQuizGeneratorScreenState();
}

class _InstructorAIQuizGeneratorScreenState
    extends State<InstructorAIQuizGeneratorScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM (Instructor Teal Palette)
  // ============================================================
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color green = Color(0xFF26A65B);

  String _selectedMaterial = 'Module 1: Intro to Flutter (PDF)';
  int _questionCount = 10;
  String _difficulty = 'Medium';

  bool _isGenerating = false;
  bool _isDraftReady = false;

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      // ==================================================
      // STANDARDIZED HEADER
      // ==================================================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: textDark,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'AI Quiz Generator',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          actions: const [
            SizedBox(
              width: 48,
            ), // Balances the leading button for center title alignment
          ],
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // Expanded to 1200 for wide desktop browsers to match other screens
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // AI CONTEXT BANNER
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primaryTeal.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: primaryTeal,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Assistant',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: primaryTeal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Generate a draft quiz based on your course materials. You can review and edit all questions before publishing to students.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textDark.withValues(alpha: 0.8),
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ==================================================
                  // CONFIGURATION SECTION
                  // ==================================================
                  if (!_isDraftReady && !_isGenerating) ...[
                    const Text(
                      '1. Select Source Material',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      value: _selectedMaterial,
                      items: [
                        'Module 1: Intro to Flutter (PDF)',
                        'Module 2: Widgets Video Transcript',
                        'Course Syllabus (PDF)',
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedMaterial = val!),
                      icon: Icons.source_rounded,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Questions',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildDropdown(
                                value: _questionCount.toString(),
                                items: ['5', '10', '15', '20'],
                                onChanged: (val) => setState(
                                  () => _questionCount = int.parse(val!),
                                ),
                                icon: Icons.format_list_numbered_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Difficulty',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildDropdown(
                                value: _difficulty,
                                items: ['Easy', 'Medium', 'Hard'],
                                onChanged: (val) =>
                                    setState(() => _difficulty = val!),
                                icon: Icons.speed_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Generate Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _simulateAIGeneration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Generate Draft Quiz',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ==================================================
                  // LOADING STATE
                  // ==================================================
                  if (_isGenerating)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: primaryTeal),
                            const SizedBox(height: 24),
                            Text(
                              'Analyzing $_selectedMaterial...',
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Generating $_questionCount $_difficulty questions',
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ==================================================
                  // GENERATED DRAFT STATE
                  // ==================================================
                  if (_isDraftReady) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. Review Draft',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _isDraftReady = false),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: textGrey,
                          ),
                          label: const Text(
                            'Discard',
                            style: TextStyle(
                              color: textGrey,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Generated Questions List
                    _buildDraftQuestionCard(
                      number: 1,
                      question: 'Which Flutter widget is used to display a string of text?',
                      options: ['Container', 'Text', 'Column', 'Scaffold'],
                      correctIndex: 1,
                    ),
                    _buildDraftQuestionCard(
                      number: 2,
                      question: 'What is the main difference between a StatelessWidget and a StatefulWidget?',
                      options: [
                        'StatelessWidgets cannot have children.',
                        'StatefulWidgets can mutate their state during runtime.',
                        'StatelessWidgets are only used for text.',
                        'There is no difference.',
                      ],
                      correctIndex: 1,
                    ),

                    const SizedBox(height: 28),

                    // Push to Moodle Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Quiz successfully pushed to Moodle!',
                              ),
                              backgroundColor: primaryTeal,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: primaryTeal,
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Publish to Moodle',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textGrey),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: textDark,
            fontSize: 13.5,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: primaryTeal),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDraftQuestionCard({
    required int number,
    required String question,
    required List<String> options,
    required int correctIndex,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Q$number',
                  style: const TextStyle(
                    color: primaryTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: textDark,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: textGrey),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (index) {
            final isCorrect = index == correctIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? green.withValues(alpha: 0.08)
                    : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? green.withValues(alpha: 0.4)
                      : const Color(0xFFE6EAF0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isCorrect ? green : textGrey,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      options[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCorrect
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isCorrect ? green : textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Fake API Call for Demo ---
  Future<void> _simulateAIGeneration() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _isDraftReady = true;
    });
  }
}
