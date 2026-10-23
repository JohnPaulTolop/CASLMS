import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ai_router_service.dart';
import '../../services/learner_assistant_service.dart';
import '../../services/school_chat_service.dart';
import 'assistant_scope_banner.dart';

class LearnerAssistantScreen extends StatefulWidget {
  const LearnerAssistantScreen({
    super.key,
    required this.role,
    this.initialStudyHelp = true,
  });
  final String role;
  final bool initialStudyHelp;
  @override
  State<LearnerAssistantScreen> createState() => _LearnerAssistantScreenState();
}

class _LearnerAssistantScreenState extends State<LearnerAssistantScreen> {
  final _service = LearnerAssistantService();
  final _studyService = SchoolChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  List<AssistantStudent> _students = [];
  StreamSubscription<User?>? _authSubscription;
  String? _uid;
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _recordsRequested = false;
  late bool _studyHelp;
  bool get _ready =>
      _studyHelp || (!_loading && _error == null && _selected != null);
  int _generation = 0;
  int _loadGeneration = 0;
  bool get _instructor => widget.role == 'instructor';
  Color get _color =>
      _instructor ? const Color(0xFF00897B) : const Color(0xFF1769FF);

  @override
  void initState() {
    super.initState();
    _studyHelp = widget.initialStudyHelp;
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid == _uid || !mounted) return;
      _uid = user?.uid;
      _input.clear();
      _resetForAccount();
    });
    _resetForAccount();
  }

  void _resetForAccount() {
    _generation++;
    _loadGeneration++;
    setState(() {
      _recordsRequested = false;
      _loading = false;
      _sending = false;
      _error = null;
      _students = [];
      _selected = null;
      _messages.clear();
    });
    if (!_studyHelp) _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _generation++;
    setState(() {
      _recordsRequested = true;
      _loading = true;
      _error = null;
      _sending = false;
      _students = [];
      _selected = null;
      _messages.clear();
    });
    try {
      final students = await _service
          .students(widget.role)
          .timeout(const Duration(seconds: 45));
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _students = students;
        _selected = students.length == 1 || !_instructor
            ? students.firstOrNull?.id
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error is LearnerAssistantException
            ? error.message
            : 'Unable to load your records. Check your connection and retry.';
      });
    }
  }

  Future<void> _send([String? suggestion]) async {
    final question = (suggestion ?? _input.text).trim();
    if (_sending || !_ready || question.isEmpty) return;
    final history = _messages
        .where((m) => !m.isError)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();
    final generation = _generation;
    _input.clear();
    setState(() {
      _sending = true;
      _messages.add(_Message(question, isUser: true));
    });
    _toBottom(force: true);
    int? streamingIndex;
    try {
      void update(String text) {
        if (!mounted || generation != _generation) return;
        setState(() {
          streamingIndex ??= _messages.length;
          if (streamingIndex == _messages.length) {
            _messages.add(_Message(text));
          } else {
            _messages[streamingIndex!] = _Message(text);
          }
        });
        _toBottom();
      }

      final String answer;
      String? records;
      if (_studyHelp) {
        answer = await _studyService.ask(
          question: question,
          history: history,
          onDelta: update,
        );
      } else {
        final reply = await _service.ask(
          role: widget.role,
          question: question,
          studentId: _selected,
          onDelta: update,
        );
        answer = reply.text;
        records = reply.usedAi ? reply.records : null;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        final message = _Message(answer, records: records);
        if (streamingIndex == null) {
          _messages.add(message);
        } else {
          _messages[streamingIndex!] = message;
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        if (streamingIndex != null) _messages.removeAt(streamingIndex!);
        _messages.add(
          _Message(
            error is LearnerAssistantException
                ? error.message
                : error is AiRouterException
                ? error.message
                : 'Unable to answer right now. Please try again.',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sending = false);
        _toBottom();
      }
    }
  }

  void _toBottom({bool force = false}) {
    if (!force && _scroll.hasClients && _scroll.position.extentAfter > 160) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          return;
        }
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _loadGeneration++;
    _authSubscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changeMode(bool study) {
    if (_sending || study == _studyHelp) return;
    setState(() {
      _studyHelp = study;
      _generation++;
      _messages.clear();
      _input.clear();
    });
    if (!study && !_recordsRequested) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            tooltip: 'New conversation',
            onPressed: _sending
                ? null
                : () => setState(() {
                    _messages.clear();
                    _input.clear();
                    _generation++;
                  }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          if (!_studyHelp)
            IconButton(
              tooltip: 'Refresh records and clear chat',
              onPressed: _sending ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  AssistantScopeBanner(color: _color),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.school_outlined, size: 18),
                        label: const Text('Study Help'),
                        selected: _studyHelp,
                        onSelected: _sending ? null : (_) => _changeMode(true),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.fact_check_outlined, size: 18),
                        label: Text(
                          _instructor ? 'Student Records' : 'My Records',
                        ),
                        selected: !_studyHelp,
                        onSelected: _sending ? null : (_) => _changeMode(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _studyHelp
                              ? 'Learn step by step, explore examples or ask how to use CAS LMS.'
                              : _instructor
                              ? 'Requirements and student records in your classes'
                              : 'Your requirements, approvals, and registered subjects',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (!_studyHelp &&
                      _instructor &&
                      !_loading &&
                      _error == null &&
                      _students.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) => DropdownMenu<String>(
                        key: ValueKey('$_generation:$_selected'),
                        width: constraints.maxWidth,
                        initialSelection: _selected,
                        enabled: !_sending,
                        enableFilter: true,
                        requestFocusOnTap: true,
                        label: const Text('Search student name or Campus ID'),
                        dropdownMenuEntries: _students
                            .map(
                              (s) => DropdownMenuEntry(
                                value: s.id,
                                label: s.label,
                              ),
                            )
                            .toList(),
                        onSelected: (value) {
                          if (_sending || value == _selected) return;
                          setState(() {
                            _selected = value;
                            _messages.clear();
                            _input.clear();
                            _generation++;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: !_studyHelp && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_studyHelp && _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : !_studyHelp && _students.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No students are actively enrolled in your classes yet.',
                        ),
                      ),
                    )
                  : _messages.isEmpty
                  ? _welcome()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _studyHelp
                                        ? 'Preparing a helpful answer…'
                                        : 'Checking current records…',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final message = _messages[index];
                        return Align(
                          alignment: message.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 760),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? _color
                                  : message.isError
                                  ? const Color(0xFFFFEBEE)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: message.isUser
                                    ? _color
                                    : const Color(0xFFE1E7F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  message.text,
                                  style: TextStyle(
                                    height: 1.5,
                                    color: message.isUser
                                        ? Colors.white
                                        : const Color(0xFF17203A),
                                  ),
                                ),
                                if (!message.isUser && !message.isError)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      tooltip: 'Copy answer',
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 17,
                                      ),
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: message.text),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text('Answer copied.'),
                                              ),
                                            );
                                      },
                                    ),
                                  ),
                                if (message.records != null)
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text(
                                      'View source records',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    children: [
                                      SelectableText(message.records!),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_studyHelp &&
                !_sending &&
                _messages.isNotEmpty &&
                !_messages.last.isError)
              _followUps(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: _ready,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _studyHelp
                            ? 'Ask about a lesson, assignment or CAS LMS…'
                            : 'Ask about these records…',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send question',
                    onPressed: _sending || !_ready ? null : () => _send(),
                    style: IconButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _followUps() {
    final limited =
        _messages.last.text.startsWith("I'm limited to CAS LMS") ||
        _messages.last.text.startsWith(
          'I can help with CAS LMS and schoolwork.',
        );
    final prompts = limited
        ? [
            'Help me with an assignment',
            'How do I submit an activity in CAS LMS?',
          ]
        : [
            'Explain more simply',
            'Show a worked example',
            'Ask me a practice question',
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: prompts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(prompts[i]),
            onPressed: () => _send(prompts[i]),
          ),
        ),
      ),
    );
  }

  Widget _welcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.smart_toy_outlined, color: _color, size: 44),
        const SizedBox(height: 14),
        Text(
          _studyHelp
              ? 'What are we learning today?'
              : _instructor
              ? 'Choose a student, then ask a question.'
              : 'What would you like to check?',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          _studyHelp
              ? 'Ask a question, then try an example or a practice question. '
                    'For your personal requirements and subjects, switch to My Records.'
              : 'Answers cover published tasks and recorded instructor decisions. '
                    'Google Form answers become verified when the instructor marks them complied.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              (_studyHelp
                      ? [
                          'Help me understand an assignment',
                          'Explain a programming concept with an example',
                          'Help outline my thesis proposal',
                          'Plan a study schedule for my exams',
                          'How do I submit an activity in CAS LMS?',
                        ]
                      : [
                          'Show missing requirements',
                          'Show approved requirements',
                          'Show pending submissions',
                          'List registered subjects',
                          'Show profile details',
                          'Help prioritize the next steps',
                        ])
                  .map(
                    (question) => ActionChip(
                      label: Text(question),
                      onPressed: !_ready ? null : () => _send(question),
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
  );
}

class _Message {
  const _Message(
    this.text, {
    this.isUser = false,
    this.isError = false,
    this.records,
  });
  final String text;
  final bool isUser;
  final bool isError;
  final String? records;
}
