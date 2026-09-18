import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/learner_assistant_service.dart';

class LearnerAssistantScreen extends StatefulWidget {
  const LearnerAssistantScreen({super.key, required this.role});
  final String role;
  @override
  State<LearnerAssistantScreen> createState() => _LearnerAssistantScreenState();
}

class _LearnerAssistantScreenState extends State<LearnerAssistantScreen> {
  final _service = LearnerAssistantService();
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
  int _generation = 0;
  bool get _instructor => widget.role == 'instructor';
  Color get _color =>
      _instructor ? const Color(0xFF00897B) : const Color(0xFF1769FF);

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid == _uid || !mounted) return;
      _uid = user?.uid;
      _input.clear();
      _load();
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
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
      if (!mounted || generation != _generation) return;
      setState(() {
        _students = students;
        _selected = students.length == 1 || !_instructor
            ? students.firstOrNull?.id
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
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
    if (_sending || _loading || _selected == null || question.isEmpty) return;
    final generation = _generation;
    _input.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _messages.add(_Message(question, isUser: true));
    });
    _toBottom();
    try {
      final reply = await _service.ask(
        role: widget.role,
        question: question,
        studentId: _selected,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _messages.add(
          _Message(reply.text, records: reply.usedAi ? reply.records : null),
        );
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _messages.add(
          _Message(
            error is LearnerAssistantException
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

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
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
    _authSubscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _instructor
                              ? 'Requirements and student records in your classes'
                              : 'Your requirements, approvals, and registered subjects',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (_instructor &&
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
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
                  : _students.isEmpty
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
                        if (index == _messages.length)
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Checking current records…'),
                          );
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_loading && !_sending && _selected != null,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about these records…',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send question',
                    onPressed: _sending || _loading || _selected == null
                        ? null
                        : () => _send(),
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

  Widget _welcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.smart_toy_outlined, color: _color, size: 44),
        const SizedBox(height: 14),
        Text(
          _instructor
              ? 'Choose a student, then ask a question.'
              : 'What would you like to check?',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Answers cover published tasks and recorded instructor decisions. '
          'Google Form answers become verified when the instructor marks them complied.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Show missing requirements',
                    'Show approved requirements',
                    'Show pending submissions',
                    'List registered subjects',
                    'Show profile details',
                    'Help prioritize the next steps',
                  ]
                  .map(
                    (question) => ActionChip(
                      label: Text(question),
                      onPressed: _selected == null
                          ? null
                          : () => _send(question),
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
