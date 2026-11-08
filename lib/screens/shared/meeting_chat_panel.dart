import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/meeting_chat_service.dart';

class MeetingChatPanel extends StatefulWidget {
  const MeetingChatPanel({
    super.key,
    required this.service,
    required this.messages,
    required this.courseId,
    required this.sectionId,
    required this.sessionId,
    this.onClose,
  });

  final MeetingChatService service;
  final Stream<List<MeetingChatMessage>> messages;
  final String courseId;
  final String sectionId;
  final String sessionId;
  final VoidCallback? onClose;

  @override
  State<MeetingChatPanel> createState() => _MeetingChatPanelState();
}

class _MeetingChatPanelState extends State<MeetingChatPanel> {
  static const _background = Color(0xFF101A2D);
  static const _surface = Color(0xFF17243A);
  static const _line = Color(0xFF26354D);
  static const _muted = Color(0xFF9AADC7);
  static const _accent = Color(0xFF72B8FF);

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastLength = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    final text = _controller.text;
    setState(() => _sending = true);
    try {
      await widget.service.sendMessage(
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        sessionId: widget.sessionId,
        text: text,
      );
      _controller.clear();
      _focus.requestFocus();
    } on MeetingChatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _followNewMessages(int length) {
    final nearBottom =
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 120;
    if (length > _lastLength && nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _lastLength = length;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, color: _accent, size: 21),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Meeting Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      tooltip: 'Close chat',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, color: _muted),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<MeetingChatMessage>>(
                stream: widget.messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _ChatState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Chat is unavailable',
                      description:
                          'Check your connection or rejoin the meeting.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _accent),
                    );
                  }
                  final messages = snapshot.data!;
                  _followNewMessages(messages.length);
                  if (messages.isEmpty) {
                    return const _ChatState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No messages yet',
                      description: 'Start the conversation for this meeting.',
                    );
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        mine: message.isMine(widget.service.currentUserId),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: const BoxDecoration(
                color: _background,
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKey,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Message everyone',
                          hintStyle: const TextStyle(color: _muted),
                          filled: true,
                          fillColor: _surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: _accent),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF10213A),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Color(0xFF10213A),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final MeetingChatMessage message;
  final bool mine;

  String _time(DateTime? value) {
    if (value == null) return 'Sending...';
    final local = value.toLocal();
    var hour = local.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF2E66AD) : const Color(0xFF1B2B43),
          border: Border.all(
            color: mine ? const Color(0xFF5687B6) : const Color(0xFF2C405D),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mine ? 15 : 4),
            bottomRight: Radius.circular(mine ? 4 : 15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    color: Color(0xFF86BDF4),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SelectableText(
              message.text,
              style: const TextStyle(
                color: Color(0xFFEAF0FC),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _time(message.createdAt),
              style: const TextStyle(color: Color(0xFF9AADC7), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatState extends StatelessWidget {
  const _ChatState({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF72B8FF), size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9AADC7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
