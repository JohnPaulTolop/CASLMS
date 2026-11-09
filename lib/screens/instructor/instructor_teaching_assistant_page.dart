import '../../core/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/instructor_teaching_ai_service.dart';
import '../shared/learner_assistant_page.dart';
import '../shared/assistant_scope_banner.dart';
import 'instructor_workspace_widgets.dart';

class InstructorTeachingAssistantScreen extends StatefulWidget {
  const InstructorTeachingAssistantScreen({super.key, this.service});
  final InstructorTeachingAiService? service;

  @override
  State<InstructorTeachingAssistantScreen> createState() =>
      _InstructorTeachingAssistantScreenState();
}

class _InstructorTeachingAssistantScreenState
    extends State<InstructorTeachingAssistantScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  Color get teal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get heading => AppColors.resolve(context, AppColors.darkText);
  Color get secondaryText =>
      AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get red => AppColors.resolve(context, AppColors.error);

  // ============================================================
  // SERVICES & STATE
  // ============================================================

  late final _service = widget.service ?? InstructorTeachingAiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<TeachingAiTurn> _messages = [];
  List<Map<String, String>> _courses = [];

  String _courseId = '';
  String? _error;
  bool _loading = true;
  bool _sending = false;

  static const prompts = [
    'Create a lesson plan about computer networks.',
    'Generate ten multiple-choice questions about cybersecurity.',
    'Create a rubric for an argumentative essay.',
    'Suggest five learning activities for Introduction to Computing.',
    'Suggest ways to improve this assessment.',
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _service.loadCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _newChat() {
    if (_sending) return;
    setState(() {
      _messages.clear();
      _error = null;
      _input.clear();
    });
  }

  Future<void> _send([String? suggestion]) async {
    final question = (suggestion ?? _input.text).trim();

    if (_loading || _sending || question.isEmpty) return;

    final history = List<TeachingAiTurn>.from(_messages);

    setState(() {
      _messages.add(TeachingAiTurn(text: question, isUser: true));
      _sending = true;
      _error = null;
      _input.clear();
    });

    _scrollDown();

    int? streamingIndex;
    try {
      final answer = await _service.ask(
        question: question,
        history: history,
        courseId: _courseId.isEmpty ? null : _courseId,
        onDelta: (text) {
          if (!mounted) return;
          setState(() {
            streamingIndex ??= _messages.length;
            if (streamingIndex == _messages.length) {
              _messages.add(TeachingAiTurn(text: text, isUser: false));
            } else {
              _messages[streamingIndex!] = TeachingAiTurn(
                text: text,
                isUser: false,
              );
            }
          });
          _scrollDown();
        },
      );

      if (!mounted) return;

      setState(() {
        if (streamingIndex == null) {
          _messages.add(TeachingAiTurn(text: answer, isUser: false));
        } else {
          _messages[streamingIndex!] = TeachingAiTurn(
            text: answer,
            isUser: false,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollDown();
      }
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Teaching AI',
                        style: TextStyle(
                          color: heading,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Student records assistant',
                      icon: const Icon(Icons.manage_accounts_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LearnerAssistantScreen(
                            role: 'instructor',
                            initialStudyHelp: false,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'New conversation',
                      onPressed: _sending ? null : _newChat,
                      icon: const Icon(Icons.edit_square),
                    ),
                    IconButton(
                      tooltip: 'About teaching AI',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: AssistantScopeBanner(
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                  ],
                ),
              ),
              _buildContextSelector(),
              if (_error != null) _buildErrorBanner(),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildChatList(),
              ),
              if (!_sending &&
                  _error == null &&
                  _messages.isNotEmpty &&
                  !_messages.last.isUser)
                _buildFollowUps(),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    ),
  );

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildFollowUps() {
    final limited =
        _messages.last.text.startsWith("I'm limited to CAS LMS") ||
        _messages.last.text.startsWith(
          'I can help with CAS LMS and schoolwork.',
        );
    final questions = limited
        ? ['Help me plan a lesson', 'How do I publish an activity in CAS LMS?']
        : [
            'Show a classroom example',
            'Adapt this for beginners',
            'Suggest a practice activity',
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: questions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(questions[i]),
            onPressed: () => _send(questions[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildContextSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 18, color: secondaryText),
          const SizedBox(width: 12),
          Text(
            'Context:',
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _loading
                ? SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(color: teal),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _courseId,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: secondaryText,
                      ),
                      style: TextStyle(
                        color: heading,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('General teaching assistance'),
                        ),
                        ..._courses.map((course) {
                          return DropdownMenuItem(
                            value: course['id']!,
                            child: Text(
                              '${course['code']} - ${course['title']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: _sending
                          ? null
                          : (value) {
                              setState(() {
                                _courseId = value ?? '';
                                _messages.clear();
                                _error = null;
                              });
                            },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: red.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: red, size: 18),
            onPressed: () => setState(() => _error = null),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => ListView(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
    children: [
      Align(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: teal, size: 27),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'What would you like to create?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: heading,
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Plan lessons, draft quizzes, build rubrics, and explore learning activities.',
        textAlign: TextAlign.center,
        style: TextStyle(color: secondaryText, height: 1.6, fontSize: 13),
      ),
      const SizedBox(height: 24),
      InstructorTiles(
        minWidth: 300,
        children: prompts.map(_buildPromptCard).toList(),
      ),
    ],
  );

  Widget _buildPromptCard(String prompt) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: borderColor),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      leading: Icon(Icons.lightbulb_outline_rounded, color: teal, size: 21),
      title: Text(
        prompt,
        style: TextStyle(
          color: heading,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_rounded,
        color: secondaryText,
        size: 18,
      ),
      onTap: _sending || _loading ? null : () => _send(prompt),
    ),
  );

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _sending) {
          return _buildTypingIndicator();
        }
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(TeachingAiTurn message) {
    final bool isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: teal,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? teal : Theme.of(context).colorScheme.surface,
                border: isUser ? null : Border.all(color: borderColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : heading,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Draft copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Preparing teaching guidance…',
            style: TextStyle(color: secondaryText, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputArea() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_sending && !_loading,
              minLines: 1,
              maxLines: 5,
              maxLength: 3000,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Plan, create, or ask a question…',
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Send to teaching AI',
            onPressed: _sending || _loading ? null : () => _send(),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ],
      ),
    ),
  );
}
