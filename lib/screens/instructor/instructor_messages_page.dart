import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/chat_service.dart';
import 'instructor_chat_page.dart';

class InstructorMessagesScreen extends StatefulWidget {
  const InstructorMessagesScreen({super.key});

  @override
  State<InstructorMessagesScreen> createState() =>
      _InstructorMessagesScreenState();
}

class _InstructorMessagesScreenState extends State<InstructorMessagesScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);

  static const Color background = Color(0xFFF7F9FC);

  static const Color textDark = Color(0xFF10182F);

  static const Color textGrey = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

  // ============================================================
  // SERVICE
  // ============================================================

  final ChatService _chatService = ChatService();

  // ============================================================
  // CACHE
  // ============================================================

  final Map<String, Future<Map<String, dynamic>?>> _courseFutures = {};

  // ============================================================
  // STATE
  // ============================================================

  String _searchQuery = '';

  // ============================================================
  // GET COURSE FUTURE
  // ============================================================

  Future<Map<String, dynamic>?> _getCourseFuture(String courseId) {
    return _courseFutures.putIfAbsent(
      courseId,
      () => _chatService.getCourseById(courseId),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,

        elevation: 0,

        foregroundColor: textDark,

        centerTitle: true,

        title: const Text(
          'Messages',

          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed: () {
              setState(() {
                _courseFutures.clear();
              });
            },

            icon: const Icon(Icons.refresh_rounded),
          ),

          const SizedBox(width: 6),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),

            child: Column(
              children: [
                // ================================================
                // SEARCH
                // ================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),

                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },

                    decoration: InputDecoration(
                      hintText: 'Search student...',

                      prefixIcon: const Icon(
                        Icons.search_rounded,

                        color: primaryTeal,
                      ),

                      filled: true,

                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),

                        borderSide: const BorderSide(color: borderColor),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),

                        borderSide: const BorderSide(color: borderColor),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),

                        borderSide: const BorderSide(
                          color: primaryTeal,

                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // ================================================
                // CONVERSATIONS
                // ================================================
                Expanded(child: _buildConversationList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION LIST
  // ============================================================

  Widget _buildConversationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.watchInstructorConversations(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: primaryTeal),
          );
        }

        if (snapshot.hasError) {
          return const Center(
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

              child: const Icon(
                Icons.forum_outlined,

                color: primaryTeal,

                size: 34,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              noSearch ? 'No conversations yet' : 'No matching students',

              style: const TextStyle(
                color: textDark,

                fontSize: 17,

                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              noSearch
                  ? 'Chats with your students will appear here.'
                  : 'Try another student name.',

              textAlign: TextAlign.center,

              style: const TextStyle(color: textGrey, fontSize: 12),
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getCourseFuture(courseId),

      builder: (context, _) {
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
              color: Colors.white,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: borderColor),
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

                        style: const TextStyle(
                          color: primaryTeal,

                          fontWeight: FontWeight.w800,

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

                                fontWeight: FontWeight.w800,
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

                              style: const TextStyle(
                                color: textDark,

                                fontSize: 14.5,

                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          if (lastMessageAt != null)
                            Text(
                              _formatTime(lastMessageAt),

                              style: const TextStyle(
                                color: textGrey,

                                fontSize: 9.5,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        courseLabel.isEmpty ? 'Course' : courseLabel,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
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

                        style: const TextStyle(color: textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.chevron_right_rounded,

                  color: Color(0xFF9BA4B4),
                ),
              ],
            ),
          ),
        );
      },
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
    try {
      final Map<String, dynamic>? student = await _chatService.getUserById(
        studentId,
      );

      if (!mounted) {
        return;
      }

      final String studentEmail = (student?['email'] ?? '').toString();

      await Navigator.push(
        context,

        MaterialPageRoute(
          builder: (context) => InstructorChatScreen(
            courseId: courseId,

            studentId: studentId,

            studentName: studentName,

            studentEmail: studentEmail,

            instructorId: instructorId,

            instructorName: instructorName,
          ),
        ),
      );
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
