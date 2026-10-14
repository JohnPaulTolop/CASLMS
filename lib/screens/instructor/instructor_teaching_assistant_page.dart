import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/instructor_teaching_ai_service.dart';
import '../shared/learner_assistant_page.dart';

class InstructorTeachingAssistantScreen extends StatefulWidget {
  const InstructorTeachingAssistantScreen({super.key});

  @override
  State<InstructorTeachingAssistantScreen> createState() =>
      _InstructorTeachingAssistantScreenState();
}

class _InstructorTeachingAssistantScreenState
    extends State<InstructorTeachingAssistantScreen> {
  static const teal = Color(0xFF00897B);

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

    try {
      final answer = await _service.ask(
        question: question,
        history: history,
        courseId: _courseId.isEmpty ? null : _courseId,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(TeachingAiTurn(text: answer, isUser: false));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('AI Teaching Assistant'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Student Records Assistant',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LearnerAssistantScreen(role: 'instructor'),
              ),
            ),
          ),
          IconButton(
            tooltip: 'New conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _sending ? null : _newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan lessons, quizzes, assignments, rubrics '
                  'and learning activities with AI.',
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LinearProgressIndicator(color: teal)
                else
                  DropdownButtonFormField<String>(
                    initialValue: _courseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Course context',
                      border: OutlineInputBorder(),
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
                const SizedBox(height: 6),
                const Text(
                  'AI suggestions are drafts. Review before use. '
                  'Chat history is kept only while this page is open.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Icon(Icons.auto_awesome, size: 45, color: teal),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'What would you like to create?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...prompts.map(
                        (prompt) => Card(
                          child: ListTile(
                            title: Text(prompt),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 15,
                            ),
                            onTap: _sending ? null : () => _send(prompt),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 730),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? const Color(0xFFD7F0EB)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(message.text),
                              if (!message.isUser)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => Clipboard.setData(
                                      ClipboardData(text: message.text),
                                    ),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy draft'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: teal,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Generating an answer...'),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_sending && !_loading,
                      maxLines: 3,
                      minLines: 1,
                      maxLength: 3000,
                      decoration: const InputDecoration(
                        hintText: 'Ask your teaching assistant...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending || _loading ? null : () => _send(),
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: teal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
