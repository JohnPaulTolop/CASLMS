import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/chat_service.dart';

class InstructorChatScreen extends StatefulWidget {
  final String courseId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String instructorId;
  final String instructorName;

  const InstructorChatScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.instructorId,
    required this.instructorName,
  });

  @override
  State<InstructorChatScreen> createState() => _InstructorChatScreenState();
}

class _InstructorChatScreenState extends State<InstructorChatScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);

  static const Color background = Color(0xFFF7F9FC);

  static const Color textDark = Color(0xFF10182F);

  static const Color textGrey = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

  // ============================================================
  // SERVICES
  // ============================================================

  final ChatService _chatService = ChatService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isInitializing = true;
  bool _isSending = false;
  bool _isMarkingRead = false;

  String? _errorMessage;
  String _conversationId = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // INITIALIZE CONVERSATION
  // ============================================================

  Future<void> _initializeConversation() async {
    try {
      final String currentUserId = _auth.currentUser?.uid ?? '';

      if (currentUserId.isEmpty) {
        throw ChatServiceException('No instructor is currently logged in.');
      }

      if (currentUserId != widget.instructorId) {
        throw ChatServiceException(
          'This chat does not belong to the logged-in instructor.',
        );
      }

      if (widget.courseId.trim().isEmpty) {
        throw ChatServiceException('Course information is missing.');
      }

      if (widget.studentId.trim().isEmpty) {
        throw ChatServiceException('Student information is missing.');
      }

      final String conversationId = await _chatService.ensureConversation(
        courseId: widget.courseId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        instructorId: widget.instructorId,
        instructorName: widget.instructorName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _conversationId = conversationId;

        _isInitializing = false;
      });

      await _markReceivedMessagesAsRead();
    } on ChatServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = 'Unable to open conversation.';
      });
    }
  }

  // ============================================================
  // SEND
  // ============================================================

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final String message = _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendMessage(
        courseId: widget.courseId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        instructorId: widget.instructorId,
        instructorName: widget.instructorName,
        receiverId: widget.studentId,
        text: message,
      );

      _messageController.clear();

      _scrollToBottom();
    } on ChatServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send message.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ============================================================
  // MARK READ
  // ============================================================

  Future<void> _markReceivedMessagesAsRead() async {
    if (_isMarkingRead) {
      return;
    }

    _isMarkingRead = true;

    try {
      await _chatService.markMessagesAsRead(
        courseId: widget.courseId,
        instructorId: widget.instructorId,
        studentId: widget.studentId,
      );
    } catch (_) {
      // Read status should not break chat.
    } finally {
      _isMarkingRead = false;
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: textDark,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        titleSpacing: 0,

        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: primaryTeal.withValues(alpha: 0.10),
              child: Text(
                _studentInitial,
                style: const TextStyle(
                  color: primaryTeal,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.studentName.trim().isEmpty
                        ? 'Student'
                        : widget.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  if (widget.studentEmail.trim().isNotEmpty)
                    Text(
                      widget.studentEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textGrey, fontSize: 10.5),
                    ),
                ],
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Conversation info',
            onPressed: _showConversationInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),

          const SizedBox(width: 6),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.redAccent,
                size: 50,
              ),

              const SizedBox(height: 14),

              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: _initializeConversation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.watchMessages(
              courseId: widget.courseId,
              instructorId: widget.instructorId,
              studentId: widget.studentId,
            ),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryTeal),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to load messages.',
                    style: TextStyle(color: textGrey),
                  ),
                );
              }

              final messages = snapshot.data ?? [];

              final String currentUid = _auth.currentUser?.uid ?? '';

              final bool hasUnread = messages.any((message) {
                return (message['receiverId'] ?? '').toString() == currentUid &&
                    message['isRead'] != true;
              });

              if (hasUnread) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markReceivedMessagesAsRead();
                });
              }

              _scrollToBottom();

              if (messages.isEmpty) {
                return _buildEmptyConversation();
              }

              return ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(messages[index]);
                },
              );
            },
          ),
        ),

        _buildMessageInput(),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyConversation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: primaryTeal,
                size: 32,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              'Start a conversation with ${widget.studentName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Messages are stored in Firestore and update in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textGrey, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    final bool isMe = (message['senderId'] ?? '').toString() == currentUserId;

    final bool isRead = message['isRead'] == true;

    final String text = (message['text'] ?? '').toString();

    final DateTime? sentAt = _toDate(message['sentAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.only(bottom: 13),

        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),

        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),

        decoration: BoxDecoration(
          color: isMe ? primaryTeal : Colors.white,

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isMe ? 17 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 17),
          ),

          border: isMe ? null : Border.all(color: borderColor),
        ),

        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,

          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : textDark,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 5),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sentAt == null ? 'Sending...' : _formatMessageTime(sentAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : textGrey,
                    fontSize: 9.5,
                  ),
                ),

                if (isMe) ...[
                  const SizedBox(width: 5),

                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),

      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach file',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Chat attachments will be connected to storage later.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.attach_file_rounded, color: textGrey),
          ),

          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isSending,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Write a message...',
                filled: true,
                fillColor: background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Container(
            decoration: const BoxDecoration(
              color: primaryTeal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Send',
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  void _showConversationInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversation Information',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 18),

                _buildInfoRow('Student', widget.studentName),

                _buildInfoRow('Email', widget.studentEmail),

                _buildInfoRow('Course ID', widget.courseId),

                _buildInfoRow('Conversation ID', _conversationId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          SelectableText(
            value.trim().isEmpty ? 'Not available' : value,
            style: const TextStyle(
              color: textDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _studentInitial {
    final String name = widget.studentName.trim();

    if (name.isEmpty) {
      return '?';
    }

    return name[0].toUpperCase();
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatMessageTime(DateTime date) {
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
