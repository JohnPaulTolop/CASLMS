import '../../core/app_colors.dart';
import '../shared/workspace_shell.dart';
import '../shared/workspace_widgets.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import 'student_chat_page.dart';

class StudentMessagesScreen extends StatefulWidget {
  const StudentMessagesScreen({super.key, this.chatService});
  final ChatService? chatService;

  @override
  State<StudentMessagesScreen> createState() => _StudentMessagesScreenState();
}

class _StudentMessagesScreenState extends State<StudentMessagesScreen> {
  Color get primaryBlue => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);

  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  late final ChatService _chatService = widget.chatService ?? ChatService();
  Stream<List<Map<String, dynamic>>>? _conversations;
  Map<String, dynamic>? _selectedContact;
  bool get _desktop =>
      MediaQuery.sizeOf(context).width >= 1100 &&
      MediaQuery.textScalerOf(context).scale(14) / 14 <= 1.4;

  List<Map<String, dynamic>> _contacts = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadContacts();
  }

  // ============================================================
  // LOAD CONTACTS
  // ============================================================

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final contacts = await _chatService.getStudentChatContacts();

      if (!mounted) {
        return;
      }

      setState(() {
        _contacts = contacts;
        _conversations = _chatService.watchStudentConversations();
        if (_selectedContact != null) {
          final index = contacts.indexWhere(
            (contact) =>
                contact['instructorId'] == _selectedContact!['instructorId'] &&
                contact['studentId'] == _selectedContact!['studentId'],
          );
          _selectedContact = index < 0 ? null : contacts[index];
        }
        _isLoading = false;
      });
    } on ChatServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load messages.';
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>> get _filteredContacts {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((contact) {
      final String instructor = (contact['instructorName'] ?? '')
          .toString()
          .toLowerCase();

      final String courseCode = (contact['courseCode'] ?? '')
          .toString()
          .toLowerCase();

      final String courseTitle = (contact['courseTitle'] ?? '')
          .toString()
          .toLowerCase();

      return instructor.contains(query) ||
          courseCode.contains(query) ||
          courseTitle.contains(query);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = workspaceInset(constraints.maxWidth);
      final heading = Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 20),
        child: const WorkspaceHeading(
          showEyebrow: false,
          title: 'Messages',
          subtitle: 'Your course conversations, in one place.',
          eyebrow: 'YOUR CONNECTIONS',
        ),
      );
      final search = Padding(
        padding: EdgeInsets.fromLTRB(
          _desktop ? 0 : inset,
          0,
          _desktop ? 0 : inset,
          14,
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            labelText: 'Search messages',
            hintText: 'Instructor or course',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      );
      final conversations = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          Expanded(child: _buildContent()),
        ],
      );
      return Scaffold(
        backgroundColor: background,
        body: _desktop
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 1100 ? 280 : 320,
                            child: conversations,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Container(
                              key: const ValueKey('desktop-conversation-pane'),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: _selectedContact == null
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.forum_outlined,
                                              color: primaryBlue,
                                              size: 34,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Choose a conversation',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Select an instructor to view your messages.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: textGrey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : _chat(_selectedContact!, embedded: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : WorkspaceScrollingBody(
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heading, search],
                ),
                body: _buildContent(),
              ),
      );
    },
  );

  Widget _chat(
    Map<String, dynamic> contact, {
    bool embedded = false,
  }) => StudentChatScreen(
    key: ValueKey(
      'chat-${contact['courseId']}:${contact['instructorId']}:${contact['studentId']}',
    ),
    courseId: (contact['courseId'] ?? '').toString(),
    studentId: (contact['studentId'] ?? '').toString(),
    studentName: (contact['studentName'] ?? 'Student').toString(),
    instructorId: (contact['instructorId'] ?? '').toString(),
    instructorName: (contact['instructorName'] ?? 'Instructor').toString(),
    instructorEmail: (contact['instructorEmail'] ?? '').toString(),
    chatService: _chatService,
    embedded: embedded,
    onClose: embedded ? () => setState(() => _selectedContact = null) : null,
  );

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _state(Widget child) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.symmetric(
      horizontal: _desktop
          ? 0
          : workspaceInset(MediaQuery.sizeOf(context).width),
    ),
    child: child,
  );

  Widget _buildContent() {
    if (_isLoading) {
      return _state(
        const WorkspaceLoadingState(label: 'Loading conversations…'),
      );
    }

    if (_errorMessage != null) {
      return _state(
        WorkspaceErrorState(
          message:
              'Unable to load messages. Check your connection and try again.',
          onRetry: _loadContacts,
        ),
      );
    }

    if (_contacts.isEmpty) {
      return _state(
        const WorkspaceEmptyState(
          icon: Icons.forum_outlined,
          title: 'No conversations yet',
          message: 'Instructors from your active courses will appear here.',
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return _state(
        const WorkspaceEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching conversations',
          message: 'Try a different instructor or course search.',
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversations,

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _state(
            WorkspaceErrorState(
              message: 'Unable to load conversation updates. Check your connection and try again.',
              onRetry: _loadContacts,
            ),
          );
        }

        final List<Map<String, dynamic>> conversations = snapshot.data ?? [];
        final conversationsByPair = <String, Map<String, dynamic>>{};
        for (final conversation in conversations) {
          final key =
              '${conversation['instructorId'] ?? ''}:${conversation['studentId'] ?? ''}';
          final current = conversationsByPair[key];
          if (current == null || _isConversationNewer(conversation, current)) {
            conversationsByPair[key] = conversation;
          }
        }

        return RefreshIndicator(
          onRefresh: _loadContacts,

          color: primaryBlue,

          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),

            padding: EdgeInsets.fromLTRB(
              _desktop ? 0 : workspaceInset(MediaQuery.sizeOf(context).width),
              0,
              _desktop ? 0 : workspaceInset(MediaQuery.sizeOf(context).width),
              24,
            ),

            itemCount: _filteredContacts.length,

            itemBuilder: (context, index) {
              final contact = _filteredContacts[index];

              final String instructorId = (contact['instructorId'] ?? '')
                  .toString();

              final String studentId = (contact['studentId'] ?? '').toString();

              final conversation =
                  conversationsByPair['$instructorId:$studentId'];

              return _buildContactCard(contact, conversation);
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _buildContactCard(
    Map<String, dynamic> contact,
    Map<String, dynamic>? conversation,
  ) {
    final name = (contact['instructorName'] ?? 'Instructor').toString();
    final shared = (contact['courseIds'] as List?)?.length ?? 0;
    final lastMessage = (conversation?['lastMessage'] ?? '').toString();
    final lastMessageAt = _toDate(conversation?['lastMessageAt']);
    final selected =
        _desktop &&
        _selectedContact?['instructorId'] == contact['instructorId'] &&
        _selectedContact?['studentId'] == contact['studentId'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        child: Material(
          elevation: 0,
          shadowColor: Colors.transparent,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('conversation-${contact['instructorId']}'),
            hoverColor: primaryBlue.withValues(alpha: .05),
            highlightColor: primaryBlue.withValues(alpha: .09),
            onTap: () {
              if (_desktop) {
                setState(() => _selectedContact = contact);
              } else {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => _chat(contact)));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: primaryBlue.withValues(alpha: .10),
                    child: Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? primaryBlue : textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (lastMessageAt != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(lastMessageAt),
                                style: TextStyle(color: textGrey, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shared == 0
                              ? 'Instructor'
                              : shared == 1
                              ? '1 shared course'
                              : '$shared shared courses',
                          style: TextStyle(color: primaryBlue, fontSize: 11),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          lastMessage.isEmpty
                              ? 'Start a conversation'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  bool _isConversationNewer(
    Map<String, dynamic> candidate,
    Map<String, dynamic> current,
  ) {
    final DateTime? candidateTime = _toDate(candidate['lastMessageAt']);
    final DateTime? currentTime = _toDate(current['lastMessageAt']);

    if (candidateTime == null) {
      return false;
    }
    if (currentTime == null) {
      return true;
    }

    return candidateTime.isAfter(currentTime);
  }

  String _formatTime(DateTime value) {
    final int hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final String minute = value.minute.toString().padLeft(2, '0');

    final String period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
