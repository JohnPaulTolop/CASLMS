import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/chat_service.dart';
import 'student_chat_page.dart';

class StudentMessagesScreen extends StatefulWidget {
  const StudentMessagesScreen({
    super.key,
  });

  @override
  State<StudentMessagesScreen> createState() =>
      _StudentMessagesScreenState();
}

class _StudentMessagesScreenState
    extends State<StudentMessagesScreen> {
  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color borderColor =
      Color(0xFFE6EAF0);

  final ChatService _chatService =
      ChatService();

  List<Map<String, dynamic>> _contacts =
      [];

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
      final contacts =
          await _chatService
              .getStudentChatContacts();

      if (!mounted) {
        return;
      }

      setState(() {
        _contacts = contacts;
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
        _errorMessage =
            'Unable to load messages.';
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>>
      get _filteredContacts {
    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where(
      (contact) {
        final String instructor =
            (contact['instructorName'] ??
                    '')
                .toString()
                .toLowerCase();

        final String courseCode =
            (contact['courseCode'] ?? '')
                .toString()
                .toLowerCase();

        final String courseTitle =
            (contact['courseTitle'] ?? '')
                .toString()
                .toLowerCase();

        return instructor.contains(query) ||
            courseCode.contains(query) ||
            courseTitle.contains(query);
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textDark,
        centerTitle: true,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment:
              Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              children: [
                // ================================================
                // SEARCH
                // ================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    12,
                  ),

                  child: TextField(
                    onChanged: (
                      value,
                    ) {
                      setState(() {
                        _searchQuery =
                            value;
                      });
                    },

                    decoration:
                        InputDecoration(
                      hintText:
                          'Search instructor or course...',

                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,
                        color:
                            primaryBlue,
                      ),

                      filled: true,

                      fillColor:
                          Colors.white,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              borderColor,
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              borderColor,
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              primaryBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(
          color: primaryBlue,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(30),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color:
                    Colors.redAccent,
                size: 48,
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: textGrey,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              TextButton.icon(
                onPressed:
                    _loadContacts,
                icon:
                    const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding:
              EdgeInsets.all(30),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                color: primaryBlue,
                size: 54,
              ),

              SizedBox(
                height: 12,
              ),

              Text(
                'No instructors available',
                style:
                    TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              SizedBox(
                height: 5,
              ),

              Text(
                'Instructors from your active courses will appear here.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color: textGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredContacts.isEmpty) {
      return const Center(
        child: Text(
          'No matching conversations.',
          style: TextStyle(
            color: textGrey,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<
        List<Map<String, dynamic>>>(
      stream:
          _chatService
              .watchMyConversations(),

      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load conversation updates.',
              style: TextStyle(
                color: textGrey,
              ),
            ),
          );
        }

        final List<Map<String, dynamic>>
            conversations =
            snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh:
              _loadContacts,

          color:
              primaryBlue,

          child: ListView.builder(
            physics:
                const AlwaysScrollableScrollPhysics(
              parent:
                  BouncingScrollPhysics(),
            ),

            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              30,
            ),

            itemCount:
                _filteredContacts.length,

            itemBuilder: (
              context,
              index,
            ) {
              final contact =
                  _filteredContacts[index];

              final String courseId =
                  (contact['courseId'] ??
                          '')
                      .toString();

              final String instructorId =
                  (contact[
                              'instructorId'] ??
                          '')
                      .toString();

              final String studentId =
                  (contact['studentId'] ??
                          '')
                      .toString();

              // ----------------------------------------------
              // Match using the exact new course-aware ID.
              // This prevents old test conversations from
              // being displayed accidentally.
              // ----------------------------------------------

              final String expectedConversationId =
                  _chatService
                      .buildConversationId(
                courseId: courseId,
                instructorId:
                    instructorId,
                studentId: studentId,
              );

              Map<String, dynamic>?
                  conversation;

              for (final item
                  in conversations) {
                if ((item['id'] ?? '')
                        .toString() ==
                    expectedConversationId) {
                  conversation = item;
                  break;
                }
              }

              return _buildContactCard(
                contact,
                conversation,
              );
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
    final String instructorName =
        (contact['instructorName'] ??
                'Instructor')
            .toString();

    final String instructorEmail =
        (contact['instructorEmail'] ??
                '')
            .toString();

    final String courseCode =
        (contact['courseCode'] ?? '')
            .toString();

    final String courseTitle =
        (contact['courseTitle'] ?? '')
            .toString();

    final String lastMessage =
        (conversation?['lastMessage'] ??
                '')
            .toString();

    final DateTime? lastMessageAt =
        _toDate(
      conversation?['lastMessageAt'],
    );

    final String initial =
        instructorName.trim().isEmpty
            ? '?'
            : instructorName
                .trim()[0]
                .toUpperCase();

    return InkWell(
      borderRadius:
          BorderRadius.circular(18),

      onTap: () {
        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (
              context,
            ) =>
                StudentChatScreen(
              courseId:
                  (contact['courseId'] ??
                          '')
                      .toString(),

              studentId:
                  (contact['studentId'] ??
                          '')
                      .toString(),

              studentName:
                  (contact['studentName'] ??
                          'Student')
                      .toString(),

              instructorId:
                  (contact[
                              'instructorId'] ??
                          '')
                      .toString(),

              instructorName:
                  instructorName,

              instructorEmail:
                  instructorEmail,
            ),
          ),
        );
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 11,
        ),

        padding:
            const EdgeInsets.all(15),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(18),

          border:
              Border.all(
            color: borderColor,
          ),
        ),

        child: Row(
          children: [
            CircleAvatar(
              radius: 23,

              backgroundColor:
                  primaryBlue.withValues(
                alpha: 0.10,
              ),

              child: Text(
                initial,

                style:
                    const TextStyle(
                  color:
                      primaryBlue,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          instructorName,

                          maxLines: 1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            color:
                                textDark,

                            fontSize:
                                14.5,

                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ),

                      if (lastMessageAt !=
                          null)
                        Text(
                          _formatTime(
                            lastMessageAt,
                          ),

                          style:
                              const TextStyle(
                            color:
                                textGrey,

                            fontSize:
                                10,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    [
                      courseCode,
                      courseTitle,
                    ]
                        .where(
                          (value) =>
                              value
                                  .trim()
                                  .isNotEmpty,
                        )
                        .join(' • '),

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      color:
                          primaryBlue,

                      fontSize:
                          11,

                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    lastMessage.isEmpty
                        ? 'Start a conversation'
                        : lastMessage,

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      color: textGrey,

                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            const Icon(
              Icons.chevron_right_rounded,

              color:
                  Color(
                0xFF9AA3B3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatTime(
    DateTime value,
  ) {
    final int hour =
        value.hour == 0
            ? 12
            : value.hour > 12
                ? value.hour - 12
                : value.hour;

    final String minute =
        value.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String period =
        value.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }
}