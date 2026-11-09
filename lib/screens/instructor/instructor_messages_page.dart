import '../../core/app_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/chat_service.dart';
import 'instructor_chat_page.dart';

class InstructorMessagesScreen extends StatefulWidget {
  const InstructorMessagesScreen({super.key, this.chatService});
  final ChatService? chatService;

  @override
  State<InstructorMessagesScreen> createState() =>
      _InstructorMessagesScreenState();
}

class _InstructorMessagesScreenState extends State<InstructorMessagesScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);

  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  // ============================================================
  // SERVICE
  // ============================================================

  late final ChatService _chatService = widget.chatService ?? ChatService();

  // ============================================================
  // CACHE
  // ============================================================

  // ============================================================
  // STATE
  // ============================================================

  String _searchQuery = '';
  Widget? _conversation;
  String? _selectedStudent;
  int _openGeneration = 0;
  late Stream<List<Map<String, dynamic>>> _conversations = _chatService
      .watchInstructorConversations();
  bool get _desktop =>
      MediaQuery.sizeOf(context).width >= 1100 &&
      MediaQuery.textScalerOf(context).scale(14) / 14 <= 1.4;

  // ============================================================
  // GET COURSE FUTURE
  // ============================================================

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => instructorScaffold(
    context: context,
    title: 'Messages',
    subtitle: 'Keep your classroom conversations close.',
    actions: [
      IconButton(
        tooltip: 'Refresh messages',
        onPressed: () => setState(() {
          _conversations = _chatService.watchInstructorConversations();
        }),
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
    body: Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final list = Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Search students',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildConversationList()),
            ],
          );
          if (!_desktop || box.maxWidth < 700) return list;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: list),
              const SizedBox(width: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:
                        _conversation ??
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forum_outlined, size: 36),
                                SizedBox(height: 14),
                                Text(
                                  'A conversation starts here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Choose a student to open your messages.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  // ============================================================
  // CONVERSATION LIST
  // ============================================================

  Widget _buildConversationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversations,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryTeal));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(30),

              child: Text(
                'Unable to load conversations.',

                textAlign: TextAlign.center,

                style: TextStyle(color: textGrey, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }

        final String instructorId = _chatService.currentUserId ?? '';

        final String query = _searchQuery.trim().toLowerCase();

        final Map<String, Map<String, dynamic>> latestByStudent =
            <String, Map<String, dynamic>>{};

        for (final Map<String, dynamic> conversation in snapshot.data ?? []) {
          if ((conversation['instructorId'] ?? '').toString() != instructorId) {
            continue;
          }

          final String studentId = (conversation['studentId'] ?? '').toString();
          final String courseId = (conversation['courseId'] ?? '').toString();

          if (studentId.isEmpty || courseId.isEmpty) {
            continue;
          }

          final Map<String, dynamic>? current = latestByStudent[studentId];

          if (current == null || _isConversationNewer(conversation, current)) {
            latestByStudent[studentId] = conversation;
          }
        }

        final List<Map<String, dynamic>> conversations = latestByStudent.values
            .where((conversation) {
              if (query.isEmpty) {
                return true;
              }

              final String studentName = (conversation['studentName'] ?? '')
                  .toString()
                  .toLowerCase();

              return studentName.contains(query);
            })
            .toList();

        conversations.sort((a, b) {
          final DateTime? aTime = _toDate(a['lastMessageAt']);
          final DateTime? bTime = _toDate(b['lastMessageAt']);

          if (aTime == null && bTime == null) {
            return 0;
          }
          if (aTime == null) {
            return 1;
          }
          if (bTime == null) {
            return -1;
          }

          return bTime.compareTo(aTime);
        });

        if (conversations.isEmpty) {
          return _buildEmptyState(query.isEmpty);
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),

          itemCount: conversations.length,

          itemBuilder: (context, index) {
            return _buildConversationCard(conversations[index]);
          },
        );
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(bool noSearch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              width: 72,

              height: 72,

              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.10),

                shape: BoxShape.circle,
              ),

              child: Icon(Icons.forum_outlined, color: primaryTeal, size: 34),
            ),

            const SizedBox(height: 15),

            Text(
              noSearch ? 'No conversations yet' : 'No matching students',

              style: TextStyle(
                color: textDark,

                fontSize: 17,

                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              noSearch
                  ? 'Chats with your students will appear here.'
                  : 'Try another student name.',

              textAlign: TextAlign.center,

              style: TextStyle(color: textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION CARD
  // ============================================================

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final String courseId = (conversation['courseId'] ?? '').toString();

    final String studentId = (conversation['studentId'] ?? '').toString();

    final String studentName = (conversation['studentName'] ?? 'Student')
        .toString();

    final String instructorId = (conversation['instructorId'] ?? '').toString();

    final String instructorName =
        (conversation['instructorName'] ?? 'Instructor').toString();

    final String lastMessage = (conversation['lastMessage'] ?? '').toString();

    final DateTime? lastMessageAt = _toDate(conversation['lastMessageAt']);

    final String initial = studentName.trim().isEmpty
        ? '?'
        : studentName.trim()[0].toUpperCase();

    const String courseLabel = 'Direct conversation';
    return InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: () async {
        await _openConversation(
          courseId: courseId,

          studentId: studentId,

          studentName: studentName,

          instructorId: instructorId,

          instructorName: instructorName,
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 11),

        padding: const EdgeInsets.all(15),

        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),

        child: Row(
          children: [
            // ================================================
            // AVATAR
            // ================================================

            Stack(
              clipBehavior: Clip.none,

              children: [
                CircleAvatar(
                  radius: 24,

                  backgroundColor: primaryTeal.withValues(alpha: 0.10),

                  child: Text(
                    initial,

                    style: TextStyle(
                      color: primaryTeal,

                      fontWeight: FontWeight.w700,

                      fontSize: 16,
                    ),
                  ),
                ),

                // ============================================
                // PER-CONVERSATION UNREAD BADGE
                // ============================================
                StreamBuilder<int>(
                  stream: _chatService.watchConversationUnreadCount(
                    courseId: courseId,

                    instructorId: instructorId,

                    studentId: studentId,
                  ),

                  builder: (context, unreadSnapshot) {
                    final int unread = unreadSnapshot.data ?? 0;

                    if (unread <= 0) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      top: -4,

                      right: -5,

                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,

                          minHeight: 19,
                        ),

                        padding: const EdgeInsets.symmetric(horizontal: 5),

                        alignment: Alignment.center,

                        decoration: BoxDecoration(
                          color: Colors.redAccent,

                          borderRadius: BorderRadius.circular(20),

                          border: Border.all(color: Colors.white, width: 2),
                        ),

                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),

                          style: const TextStyle(
                            color: Colors.white,

                            fontSize: 8.5,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(width: 14),

            // ================================================
            // TEXT
            // ================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            color: _selectedStudent == studentId
                                ? primaryTeal
                                : textDark,

                            fontSize: 14.5,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      if (lastMessageAt != null)
                        Text(
                          _formatTime(lastMessageAt),

                          style: TextStyle(color: textGrey, fontSize: 9.5),
                        ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Text(
                    courseLabel.isEmpty ? 'Course' : courseLabel,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: primaryTeal,

                      fontSize: 10.5,

                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    lastMessage.isEmpty ? 'No messages yet' : lastMessage,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9BA4B4)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPEN CHAT
  // ============================================================

  Future<void> _openConversation({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
  }) async {
    final generation = ++_openGeneration;
    try {
      final Map<String, dynamic>? student = await _chatService.getUserById(
        studentId,
      );

      if (!mounted) {
        return;
      }

      if (generation != _openGeneration) return;
      final String studentEmail = (student?['email'] ?? '').toString();

      final chat = InstructorChatScreen(
        key: ValueKey('chat-$studentId'),
        courseId: courseId,
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        instructorId: instructorId,
        instructorName: instructorName,
        embedded: _desktop,
        chatService: _chatService,
        onClose: () => setState(() {
          _conversation = null;
          _selectedStudent = null;
        }),
      );
      if (_desktop) {
        setState(() {
          _selectedStudent = studentId;
          _conversation = chat;
        });
      } else {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => chat));
      }
    } on ChatServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),

          behavior: SnackBarBehavior.floating,

          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
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

  String _formatTime(DateTime date) {
    final DateTime now = DateTime.now();

    final bool today =
        now.year == date.year && now.month == date.month && now.day == date.day;

    if (!today) {
      return '${date.month}/${date.day}';
    }

    final int hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final String minute = date.minute.toString().padLeft(2, '0');

    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
