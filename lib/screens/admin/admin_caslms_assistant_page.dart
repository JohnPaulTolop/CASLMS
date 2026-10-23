import 'package:flutter/material.dart';

import '../../services/admin_assistant_service.dart';
import '../shared/assistant_scope_banner.dart';

class AdminCaslmsAssistantScreen extends StatefulWidget {
  const AdminCaslmsAssistantScreen({super.key});

  @override
  State<AdminCaslmsAssistantScreen> createState() =>
      _AdminCaslmsAssistantScreenState();
}

class _AdminCaslmsAssistantScreenState
    extends State<AdminCaslmsAssistantScreen> {
  static const Color primary = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF7F8FC);
  static const Color darkText = Color(0xFF17203A);
  static const Color mutedText = Color(0xFF68738A);
  static const Color border = Color(0xFFE4E7EF);

  final AdminAssistantService _assistant = AdminAssistantService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  final List<_AssistantMessage> _messages = <_AssistantMessage>[
    const _AssistantMessage(
      text:
          'Hello! I can securely read CASLMS records and help you find '
          'student details, registered subjects, approved applications, '
          'completed assessments, and missing requirements. What would you '
          'like to check?',
      isUser: false,
    ),
  ];

  bool _isSending = false;

  static const List<String> _suggestions = <String>[
    'Show students with missing requirements',
    'List students and their registered subjects',
    'Show approved instructor applications',
    'Give me a CASLMS records overview',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedQuestion]) async {
    if (_isSending) {
      return;
    }

    final String question = (suggestedQuestion ?? _messageController.text)
        .trim();

    if (question.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    _messageController.clear();

    setState(() {
      _isSending = true;
      _messages.add(_AssistantMessage(text: question, isUser: true));
    });

    _scrollToBottom();

    try {
      final String answer = await _assistant.ask(question);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(_AssistantMessage(text: answer, isUser: false));
        _isSending = false;
      });
    } on AdminAssistantException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AssistantMessage(text: error.message, isUser: false, isError: true),
        );
        _isSending = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          const _AssistantMessage(
            text: 'Unable to process that request right now. Please try again.',
            isUser: false,
            isError: true,
          ),
        );
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearConversation() {
    if (_isSending) {
      return;
    }

    setState(() {
      _messages
        ..clear()
        ..add(
          const _AssistantMessage(
            text:
                'Conversation cleared. What CASLMS record would you like '
                'me to analyze?',
            isUser: false,
          ),
        );
      _assistant.clearCache();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Row(
          children: <Widget>[
            _AssistantAvatar(size: 38),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CASLMS Assistant',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Admin records analysis',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _isSending ? null : _clearConversation,
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: AssistantScopeBanner(color: primary),
          ),
          _buildPrivacyNotice(),
          Expanded(child: _buildMessages()),
          _buildSuggestions(),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.admin_panel_settings_outlined, color: primary, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Admin only. Answers use current Firestore records. Always '
              'verify a record before making an official decision.',
              style: TextStyle(
                color: Color(0xFF3730A3),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (_isSending && index == _messages.length) {
          return const _ThinkingBubble();
        }

        return _MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildSuggestions() {
    if (_messages.length > 2) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String suggestion = _suggestions[index];

          return ActionChip(
            onPressed: _isSending ? null : () => _send(suggestion),
            avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(suggestion),
            labelStyle: const TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) {
                  if (!_isSending) {
                    _send();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Ask about a student, subject, or requirement...',
                  hintStyle: const TextStyle(color: mutedText, fontSize: 12),
                  filled: true,
                  fillColor: background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _isSending ? null : _send,
              tooltip: 'Send',
              style: IconButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.45),
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;
    final Color bubbleColor = isUser
        ? _AdminCaslmsAssistantScreenState.primary
        : message.isError
        ? const Color(0xFFFFEBEE)
        : Colors.white;
    final Color textColor = isUser
        ? Colors.white
        : message.isError
        ? const Color(0xFFB42318)
        : _AdminCaslmsAssistantScreenState.darkText;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!isUser) ...<Widget>[
              const _AssistantAvatar(size: 31),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17),
                    topRight: const Radius.circular(17),
                    bottomLeft: Radius.circular(isUser ? 17 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 17),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: message.isError
                              ? const Color(0xFFFECACA)
                              : _AdminCaslmsAssistantScreenState.border,
                        ),
                  boxShadow: isUser
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.025),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: size * 0.58,
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AssistantAvatar(size: 31),
            SizedBox(width: 9),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(17)),
                border: Border.fromBorderSide(
                  BorderSide(color: _AdminCaslmsAssistantScreenState.border),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _AdminCaslmsAssistantScreenState.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
