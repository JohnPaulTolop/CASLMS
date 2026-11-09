import '../../core/app_colors.dart';
import 'workspace_widgets.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ai_router_service.dart';
import '../../services/learner_assistant_service.dart';
import '../../services/school_chat_service.dart';
import '../../services/assistant_attachment_service.dart';
import '../../services/assistant_history_service.dart';
import 'assistant_conversation_widgets.dart';
import 'assistant_material_picker.dart';

class LearnerAssistantScreen extends StatefulWidget {
  const LearnerAssistantScreen({
    super.key,
    required this.role,
    this.initialStudyHelp = true,
    this.initialPrompt,
    this.auth,
    this.service,
    this.studyService,
    this.attachmentService,
    this.showBackButton = false,
    this.initialCourseId,
  });
  final String role;
  final String? initialPrompt;
  final bool initialStudyHelp;
  final FirebaseAuth? auth;
  final LearnerAssistantService? service;
  final SchoolChatService? studyService;
  final AssistantAttachmentService? attachmentService;
  final bool showBackButton;
  final String? initialCourseId;
  @override
  State<LearnerAssistantScreen> createState() => _LearnerAssistantScreenState();
}

class _LearnerAssistantScreenState extends State<LearnerAssistantScreen> {
  late final LearnerAssistantService _service;
  late final SchoolChatService _studyService;
  late final FirebaseAuth _auth;
  late final AssistantAttachmentService _attachmentService;
  final _attachments = <AssistantAttachment>[];
  bool _attaching = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  final _historyService = AssistantHistoryService();
  String _conversationId = DateTime.now().microsecondsSinceEpoch.toString();
  bool _hadAttachments = false;
  bool _historyErrorShown = false;
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

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _service = widget.service ?? LearnerAssistantService();
    _studyService = widget.studyService ?? SchoolChatService();
    _attachmentService =
        widget.attachmentService ?? AssistantAttachmentService();
    _studyHelp = widget.initialStudyHelp;
    _uid = _auth.currentUser?.uid;
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user?.uid == _uid || !mounted) return;
      unawaited(_persistHistory());
      _uid = user?.uid;
      _input.clear();
      _resetForAccount();
    });
    _resetForAccount();
    _input.text = widget.initialPrompt ?? '';
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
      _attachments.clear();
      _attaching = false;
      _conversationId = '${DateTime.now().microsecondsSinceEpoch}:$_generation';
      _hadAttachments = false;
      _historyErrorShown = false;
    });
    if (!_studyHelp) _load();
  }

  Future<void> _load() async {
    unawaited(_persistHistory());
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
      _conversationId = '${DateTime.now().microsecondsSinceEpoch}:$_generation';
      _hadAttachments = false;
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
    if (_sending || _attaching || !_ready || question.isEmpty) return;
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
      _hadAttachments = _hadAttachments || _attachments.isNotEmpty;
    });
    unawaited(_persistHistory());
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
        await _attachmentService
            .validateAccess(_attachments)
            .timeout(const Duration(seconds: 45));
        if (!mounted || generation != _generation) return;
        answer = await _studyService.ask(
          question: question,
          history: history,
          attachments: List.of(_attachments),
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
                : error is FormatException
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
        unawaited(_persistHistory());
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
    unawaited(_persistHistory());
    setState(() {
      _studyHelp = study;
      _generation++;
      _messages.clear();
      _input.clear();
      _attachments.clear();
      _conversationId = '${DateTime.now().microsecondsSinceEpoch}:$_generation';
      _hadAttachments = false;
    });
    if (!study && !_recordsRequested) _load();
  }

  void _newConversation() {
    unawaited(_persistHistory());
    setState(() {
      _messages.clear();
      _input.clear();
      _attachments.clear();
      _generation++;
      _conversationId = '${DateTime.now().microsecondsSinceEpoch}:$_generation';
      _hadAttachments = false;
    });
  }

  Future<void> _persistHistory() async {
    final uid = _uid;
    if (uid == null || _messages.isEmpty) return;
    final finished = List<_Message>.of(_messages);
    if (_sending && finished.isNotEmpty && !finished.last.isUser) {
      finished.removeLast();
    }
    if (finished.isEmpty) return;
    final title =
        finished.where((message) => message.isUser).firstOrNull?.text ??
        'Conversation';
    final entry = AssistantHistoryEntry(
      id: _conversationId,
      title: title,
      updated: DateTime.now(),
      studyHelp: _studyHelp,
      studentId: _selected,
      hasAttachments: _hadAttachments,
      messages: finished
          .skip(finished.length > 80 ? finished.length - 80 : 0)
          .map(
            (message) => <String, dynamic>{
              'text': message.text,
              'isUser': message.isUser,
              'isError': message.isError,
            },
          )
          .toList(),
    );
    try {
      await _historyService.save(uid, widget.role, entry);
    } catch (_) {
      if (mounted && _uid == uid && !_historyErrorShown) {
        _historyErrorShown = true;
        _notice(
          'Chat history could not be saved on this device. Check available browser storage.',
        );
      }
    }
  }

  Future<void> _openHistory() async {
    final uid = _uid;
    final generation = _generation;
    if (uid == null) return;
    await _persistHistory();
    final List<AssistantHistoryEntry> entries;
    try {
      entries = await _historyService.load(uid, widget.role);
    } catch (_) {
      _notice('Unable to open chat history on this device.');
      return;
    }
    if (!mounted || uid != _uid || generation != _generation) return;
    final selected = await showModalBottomSheet<AssistantHistoryEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        initialData: _auth.currentUser,
        builder: (context, account) {
          if (account.data?.uid != uid) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sign in again to view your history.'),
              ),
            );
          }
          return StatefulBuilder(
            builder: (context, updateSheet) => SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Chat history',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close history',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const Text(
                        'Saved on this device for your account. Files and source-record snapshots are not saved.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: entries.isEmpty
                            ? const Center(
                                child: Text(
                                  'Your conversations will appear here.',
                                ),
                              )
                            : ListView.builder(
                                itemCount: entries.length,
                                itemBuilder: (context, index) {
                                  final item = entries[index];
                                  return ListTile(
                                    title: Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${item.studyHelp ? 'Study help' : 'Records'} · ${MaterialLocalizations.of(context).formatShortDate(item.updated.toLocal())}',
                                    ),
                                    onTap: () => Navigator.pop(context, item),
                                    trailing: IconButton(
                                      tooltip: 'Delete conversation',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () async {
                                        if (_auth.currentUser?.uid != uid) {
                                          return;
                                        }
                                        try {
                                          await _historyService.delete(
                                            uid,
                                            widget.role,
                                            item.id,
                                          );
                                          if (!context.mounted) return;
                                          updateSheet(
                                            () => entries.removeWhere(
                                              (entry) => entry.id == item.id,
                                            ),
                                          );
                                          if (mounted &&
                                              _conversationId == item.id) {
                                            setState(() {
                                              _messages.clear();
                                              _input.clear();
                                              _attachments.clear();
                                              _generation++;
                                              _conversationId =
                                                  '${DateTime.now().microsecondsSinceEpoch}:$_generation';
                                              _hadAttachments = false;
                                            });
                                          }
                                        } catch (_) {
                                          _notice(
                                            'Unable to delete this conversation.',
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || uid != _uid || selected == null) return;
    setState(() {
      _generation++;
      _messages.clear();
      _input.clear();
      _attachments.clear();
      _studyHelp = selected.studyHelp;
    });
    if (!selected.studyHelp) {
      final loading = _load();
      final restoreGeneration = _generation;
      await loading;
      if (!mounted ||
          uid != _uid ||
          _error != null ||
          restoreGeneration != _generation) {
        return;
      }
      if (!_students.any((student) => student.id == selected.studentId)) {
        _notice('These records are no longer available for this account.');
        return;
      }
    }
    if (!mounted || uid != _uid) return;
    setState(() {
      _conversationId = selected.id;
      _selected = selected.studyHelp ? _selected : selected.studentId;
      _hadAttachments = selected.hasAttachments;
      _messages.addAll(
        selected.messages.map(
          (message) => _Message(
            message['text'] as String,
            isUser: message['isUser'] == true,
            isError: message['isError'] == true,
          ),
        ),
      );
    });
    if (selected.hasAttachments) {
      _notice('Reattach files or links to use them in your next question.');
    }
    _toBottom(force: true);
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _attach() async {
    final generation = _generation;
    final source = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload a file'),
              subtitle: const Text(
                'PDF, text, Word, PowerPoint or Excel · up to 5 MB',
              ),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            if (widget.role == 'student')
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Choose from modules'),
                subtitle: const Text('Published materials from your courses'),
                onTap: () => Navigator.pop(context, 'module'),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || generation != _generation || source == null) return;
    setState(() => _attaching = source == 'file');
    try {
      final AssistantAttachment? item;
      if (source == 'module') {
        item = await showModalBottomSheet<AssistantAttachment>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => AssistantMaterialPicker(
            service: _attachmentService,
            initialCourseId: widget.initialCourseId,
          ),
        );
      } else {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: AssistantAttachmentService.extensions,
        );
        if (file == null) return;
        if (await file.length() > AssistantAttachmentService.maxBytes) {
          throw const FormatException(
            'Choose a readable document smaller than 5 MB.',
          );
        }
        item = await AssistantAttachmentService.fromBytes(
          file.name,
          await file.readAsBytes(),
        );
      }
      if (!mounted || generation != _generation || item == null) return;
      final attachment = item;
      setState(() {
        if (_attachments.length < 3) _attachments.add(attachment);
      });
    } catch (error) {
      if (generation == _generation) {
        _notice(
          error is FormatException ? error.message : 'Unable to read this file. Try a text-based PDF or an Office document.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _attaching = false);
      }
    }
  }

  Future<void> _addLink() async {
    final generation = _generation;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a reference link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The link is shared as a reference. Attach a document to discuss its contents.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 500,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://…'),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add link'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || value == null || generation != _generation) return;
    try {
      final item = AssistantAttachmentService.fromLink(value);
      setState(() {
        if (_attachments.length < 3) _attachments.add(item);
      });
    } on FormatException catch (error) {
      _notice(error.message);
    }
  }

  void _showHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Your study assistant'),
      content: const SingleChildScrollView(
        child: Text(
          'Ask about lessons, assignments, research or using CAS LMS. Switch to My Records for permitted personal record lookups.\n\n'
          'Attach up to 3 documents or choose published module materials. Relevant text excerpts are shared with each question; large documents may not be fully represented. Scanned PDFs and images need a text version. PDF reading is available on the web.\n\n'
          'Links are references only; webpage and video contents are not fetched. Attachments are cleared when you start a new chat, switch modes or sign out. Never attach passwords or private credentials.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      top: widget.showBackButton,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AssistantConversationToolbar(
                  studyHelp: _studyHelp,
                  instructor: _instructor,
                  enabled: !_sending && !_attaching,
                  onModeChanged: _changeMode,
                  onNew: _newConversation,
                  onInfo: _showHelp,
                  onHistory: _uid == null ? null : _openHistory,
                  onRefresh: _studyHelp ? null : _load,
                  onBack: widget.showBackButton
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
              ),
              if (!_studyHelp &&
                  _instructor &&
                  !_loading &&
                  _error == null &&
                  _students.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, box) => DropdownMenu<String>(
                      key: ValueKey('$_generation:$_selected'),
                      width: box.maxWidth,
                      initialSelection: _selected,
                      enabled: !_sending,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      label: const Text('Search student name or Campus ID'),
                      dropdownMenuEntries: [
                        for (final student in _students)
                          DropdownMenuEntry(
                            value: student.id,
                            label: student.label,
                          ),
                      ],
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
                ),
              Expanded(
                child: !_studyHelp && _loading
                    ? const WorkspaceLoadingState(label: 'Loading records…')
                    : !_studyHelp && _error != null
                    ? WorkspaceErrorState(message: _error!, onRetry: _load)
                    : !_studyHelp && _students.isEmpty
                    ? const WorkspaceEmptyState(
                        icon: Icons.people_outline,
                        title: 'No active records yet',
                        message: 'Your available records will appear here.',
                      )
                    : _messages.isEmpty
                    ? _welcome()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Thinking…',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _message(_messages[index]);
                        },
                      ),
              ),
              if (_studyHelp &&
                  !_sending &&
                  _messages.isNotEmpty &&
                  !_messages.last.isError)
                _followUps(),
              if (_attaching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: LinearProgressIndicator(),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: AssistantComposer(
                  controller: _input,
                  ready: _ready,
                  busy: _sending || _attaching,
                  studyHelp: _studyHelp,
                  attachments: _attachments,
                  onAttach: _attach,
                  onLink: _addLink,
                  onRemove: (index) =>
                      setState(() => _attachments.removeAt(index)),
                  onSend: () => _send(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _message(_Message message) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 760),
      margin: const EdgeInsets.only(bottom: 20),
      padding: message.isUser || message.isError
          ? const EdgeInsets.all(14)
          : const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: message.isUser
            ? AppColors.resolve(context, AppColors.blueTint)
            : message.isError
            ? Theme.of(context).colorScheme.errorContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.text,
            style: TextStyle(
              height: 1.55,
              fontSize: 14,
              color: message.isError
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (!message.isUser && !message.isError)
            IconButton(
              tooltip: 'Copy answer',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message.text));
                _notice('Answer copied.');
              },
            ),
          if (message.records != null)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'View source records',
                style: TextStyle(fontSize: 12),
              ),
              children: [SelectableText(message.records!)],
            ),
        ],
      ),
    ),
  );

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
              ? 'Bring a question, a lesson, or a module material. Let’s work through it.'
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
