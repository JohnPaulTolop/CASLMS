import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/instructor_teaching_ai_service.dart';
import '../shared/learner_assistant_page.dart';
import '../shared/assistant_scope_banner.dart';

class InstructorTeachingAssistantScreen extends StatefulWidget {
  const InstructorTeachingAssistantScreen({super.key});

  @override
  State<InstructorTeachingAssistantScreen> createState() =>
      _InstructorTeachingAssistantScreenState();
}

class _InstructorTeachingAssistantScreenState
    extends State<InstructorTeachingAssistantScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color teal = Color(0xFF00897B);
  static const Color background = Color(0xFFF5F8FC);
  static const Color heading = Color(0xFF172B4D);
  static const Color secondaryText = Color(0xFF6B7C93);
  static const Color borderColor = Color(0xFFE5ECF3);
  static const Color red = Color(0xFFFF4B4B);

  // ============================================================
  // SERVICES & STATE
  // ============================================================

  final _service = InstructorTeachingAiService();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: heading),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teaching Assistant',
              style: TextStyle(
                color: heading,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'AI Lesson & Assessment Builder',
              style: TextStyle(
                color: secondaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Student Records Assistant',
            icon: const Icon(Icons.manage_accounts_outlined, color: heading),
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
            icon: const Icon(Icons.add_comment_outlined, color: teal),
            onPressed: _sending ? null : _newChat,
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: AssistantScopeBanner(color: teal),
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
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 18, color: secondaryText),
          const SizedBox(width: 12),
          const Text(
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
                ? const SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(color: teal),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _courseId,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: secondaryText,
                      ),
                      style: const TextStyle(
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD6D6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: red, size: 18),
            onPressed: () => setState(() => _error = null),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 32, color: teal),
        ),
        const SizedBox(height: 20),
        const Text(
          'What would you like to create?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Plan lessons, generate quizzes, build rubrics, and\norganize learning activities instantly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryText, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 40),
        ...prompts.map((prompt) => _buildPromptCard(prompt)),
      ],
    );
  }

  Widget _buildPromptCard(String prompt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        leading: const Icon(
          Icons.lightbulb_outline_rounded,
          color: teal,
          size: 22,
        ),
        title: Text(
          prompt,
          style: const TextStyle(
            color: heading,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: secondaryText,
        ),
        onTap: _sending ? null : () => _send(prompt),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(20),
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
            const CircleAvatar(
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
                color: isUser ? teal : Colors.white,
                border: isUser ? null : Border.all(color: borderColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  if (!isUser)
                    BoxShadow(
                      color: heading.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
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
                              const Text(
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: teal,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: teal),
                ),
                SizedBox(width: 12),
                Text(
                  'Preparing teaching guidance…',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _input,
                enabled: !_sending && !_loading,
                maxLines: 5,
                minLines: 1,
                maxLength: 3000,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 14, color: heading),
                decoration: const InputDecoration(
                  hintText: 'Ask your teaching assistant...',
                  hintStyle: TextStyle(color: secondaryText, fontSize: 14),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              color: teal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Send message',
              onPressed: _sending || _loading
                  ? null
                  : () {
                      if (_input.text.trim().isNotEmpty) _send();
                    },
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
