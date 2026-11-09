import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/chat_service.dart';
import '../shared/chat_message_content.dart';
import '../shared/workspace_widgets.dart';

class StudentChatScreen extends StatefulWidget {
  final String courseId;
  final String studentId;
  final String studentName;
  final String instructorId;
  final String instructorName;
  final String instructorEmail;
  final ChatService? chatService;
  final bool embedded;
  final VoidCallback? onClose;
  final Future<PlatformFile?> Function()? attachmentPicker;

  const StudentChatScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.instructorId,
    required this.instructorName,
    required this.instructorEmail,
    this.chatService,
    this.embedded = false,
    this.onClose,
    this.attachmentPicker,
  });

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  Color get primaryBlue => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);

  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  late final ChatService _chatService = widget.chatService ?? ChatService();
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  bool _isInitializing = true;
  bool _isSending = false;
  bool _markingRead = false;

  String? _errorMessage;

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
  // INITIALIZE
  // ============================================================

  Future<void> _initializeConversation() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    try {
      final String currentUid = _chatService.currentUserId ?? '';

      if (currentUid.isEmpty) {
        throw ChatServiceException('No student is currently logged in.');
      }

      if (currentUid != widget.studentId) {
        throw ChatServiceException(
          'This conversation does not belong to the logged-in student.',
        );
      }

      if (widget.courseId.trim().isEmpty) {
        throw ChatServiceException('Course information is missing.');
      }

      await _chatService.ensureConversation(
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
        _messagesStream = _chatService.watchMessages(
          courseId: widget.courseId,
          instructorId: widget.instructorId,
          studentId: widget.studentId,
        );
        _isInitializing = false;
      });

      await _markRead();
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
    final String text = _messageController.text.trim();

    if (text.isEmpty || _isSending) {
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
        receiverId: widget.instructorId,
        text: text,
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

  Future<void> _pickAndSendAttachment() async {
    if (_isSending || _isInitializing) return;
    final uid = _chatService.currentUserId;
    final caption = _messageController.text;
    setState(() => _isSending = true);
    try {
      final file =
          await (widget.attachmentPicker?.call() ??
              FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: const [
                  'pdf',
                  'doc',
                  'docx',
                  'ppt',
                  'pptx',
                  'xls',
                  'xlsx',
                  'txt',
                  'jpg',
                  'jpeg',
                  'png',
                  'gif',
                  'webp',
                ],
              ));
      if (file == null || !mounted) return;
      if (await file.length() > ChatService.maximumAttachmentBytes) {
        throw ChatServiceException(
          'Chat attachments must be 15 MB or smaller.',
        );
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (uid == null ||
          uid != widget.studentId ||
          _chatService.currentUserId != uid) {
        throw ChatServiceException(
          'Your session changed. Reopen the conversation.',
        );
      }
      await _chatService.sendAttachment(
        courseId: widget.courseId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        instructorId: widget.instructorId,
        instructorName: widget.instructorName,
        receiverId: widget.instructorId,
        fileName: file.name,
        fileBytes: bytes,
        caption: caption,
      );
      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ChatServiceException
                  ? error.message
                  : 'Unable to read or send this attachment.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markRead() async {
    if (_markingRead) {
      return;
    }

    _markingRead = true;

    try {
      await _chatService.markMessagesAsRead(
        courseId: widget.courseId,
        instructorId: widget.instructorId,
        studentId: widget.studentId,
      );
    } catch (_) {
      // Do not break UI if read status fails.
    } finally {
      _markingRead = false;
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isInitializing && !widget.embedded) return const PageLoadingState();
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        centerTitle: false,
        actions: [
          if (widget.embedded)
            IconButton(
              tooltip: 'Close conversation',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        backgroundColor: AppColors.resolve(context, Colors.white),
        foregroundColor: textDark,
        elevation: 0,

        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: primaryBlue.withValues(alpha: 0.10),
              child: Text(
                _instructorInitial,
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.instructorName.trim().isEmpty
                        ? 'Instructor'
                        : widget.instructorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (widget.instructorEmail.trim().isNotEmpty)
                    Text(
                      widget.instructorEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textGrey, fontSize: 10.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(child: _buildBody()),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isInitializing) {
      return Center(child: CircularProgressIndicator(color: primaryBlue));
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
                size: 48,
              ),

              const SizedBox(height: 12),

              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontWeight: FontWeight.w600),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,

                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: primaryBlue),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load messages.',
                        style: TextStyle(color: textGrey),
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  final String uid = _chatService.currentUserId ?? '';

                  final bool hasUnread = messages.any((message) {
                    return (message['receiverId'] ?? '').toString() == uid &&
                        message['isRead'] != true;
                  });

                  if (hasUnread) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markRead();
                    });
                  }

                  _scrollToBottom();

                  if (messages.isEmpty) {
                    return _buildEmpty();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildBubble(messages[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ),
        _buildInput(),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: WorkspaceEmptyState(
        icon: Icons.forum_outlined,
        title: 'Start a conversation',
        message: 'Send a message to ${widget.instructorName} to begin.',
      ),
    );
  }

  // ============================================================
  // BUBBLE
  // ============================================================

  Widget _buildBubble(Map<String, dynamic> message) {
    final String uid = _chatService.currentUserId ?? '';

    final bool isMe = (message['senderId'] ?? '').toString() == uid;

    final bool isRead = message['isRead'] == true;

    final DateTime? sentAt = message['sentAt'] is Timestamp
        ? (message['sentAt'] as Timestamp).toDate()
        : null;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,

        child: Container(
          margin: const EdgeInsets.only(bottom: 12),

          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .82),

          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),

          decoration: BoxDecoration(
            color: isMe
                ? primaryBlue
                : AppColors.resolve(context, Colors.white),

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
              ChatMessageContent(
                message: message,
                isMine: isMe,
                accentColor: primaryBlue,
                textColor: isMe
                    ? Theme.of(context).colorScheme.onPrimary
                    : textDark,
              ),

              const SizedBox(height: 5),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sentAt == null ? 'Sending...' : _formatTime(sentAt),
                    style: TextStyle(
                      color: isMe
                          ? Theme.of(context).colorScheme.onPrimary
                                .withValues(alpha: .72)
                          : textGrey,
                      fontSize: 9.5,
                    ),
                  ),

                  if (isMe) ...[
                    const SizedBox(width: 5),

                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimary
                          .withValues(alpha: isRead ? 1 : .6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInput() {
    return Container(
      key: const ValueKey('message-composer-surface'),
      width: double.infinity,

      decoration: BoxDecoration(
        color: AppColors.resolve(context, Colors.white),
        border: Border(top: BorderSide(color: borderColor)),
      ),

      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                IconButton(
                  tooltip: 'Attach photo or file',
                  onPressed: _isSending ? null : _pickAndSendAttachment,
                  icon: Icon(Icons.attach_file_rounded, color: primaryBlue),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Message',
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
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                  ),

                  child: IconButton(
                    tooltip: _isSending ? 'Sending message' : 'Send message',
                    onPressed: _isSending ? null : _sendMessage,

                    icon: _isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _instructorInitial {
    final String name = widget.instructorName.trim();

    if (name.isEmpty) {
      return '?';
    }

    return name[0].toUpperCase();
  }

  String _formatTime(DateTime date) {
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
