import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

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
  Color get primary => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get darkText => AppColors.resolve(context, AppColors.darkText);
  Color get mutedText => AppColors.resolve(context, AppColors.secondaryText);
  Color get border => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get blueTint => AppColors.resolve(context, AppColors.blueTint);

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
    final width = MediaQuery.sizeOf(context).width;
    final inset = workspaceInset(width);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, 12, inset, 8),
                  child: WorkspaceHeading(
                    showEyebrow: false,
                    title: 'CASLMS Assistant',
                    subtitle: 'Secure records analysis for students, subjects, applications, and requirements.',
                    eyebrow: 'ADMINISTRATION',
                    actions: [
                      IconButton(
                        onPressed: _isSending ? null : _clearConversation,
                        tooltip: 'Clear conversation',
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                  child: const AssistantScopeBanner(
                    color: AppColors.primaryBlue,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: _buildPrivacyNotice(),
                ),
                Expanded(child: _buildMessages(inset)),
                _buildSuggestions(inset),
                _buildComposer(inset),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return WorkspaceSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: AppColors.resolve(context, AppColors.noticeboard),
      borderColor: AppColors.resolve(context, AppColors.noticeboard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.admin_panel_settings_outlined, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Admin only. Answers use current Firestore records. Always '
              'verify a record before making an official decision.',
              style: TextStyle(
                color: darkText,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(double inset) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(inset, 14, inset, 12),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (_isSending && index == _messages.length) {
          return const _ThinkingBubble();
        }

        return _MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildSuggestions(double inset) {
    if (_messages.length > 2) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String suggestion = _suggestions[index];

          return ActionChip(
            onPressed: _isSending ? null : () => _send(suggestion),
            avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: primary),
            label: Text(suggestion),
            labelStyle: TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: surface,
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer(double inset) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(inset, 10, inset, 14),
        decoration: BoxDecoration(
          color: surface,
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
                  hintStyle: TextStyle(color: mutedText, fontSize: 13),
                  filled: true,
                  fillColor: background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primary, width: 1.5),
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
    final primary = AppColors.resolve(context, AppColors.primaryBlue);
    final surface = AppColors.resolve(context, Colors.white);
    final darkText = AppColors.resolve(context, AppColors.darkText);
    final border = AppColors.resolve(context, AppColors.inputBorder);
    final error = AppColors.resolve(context, AppColors.error);

    final Color bubbleColor = isUser
        ? primary
        : message.isError
        ? error.withValues(alpha: 0.08)
        : surface;
    final Color textColor = isUser
        ? Colors.white
        : message.isError
        ? error
        : darkText;

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
              const _AssistantAvatar(size: 32),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: message.isError
                              ? error.withValues(alpha: 0.3)
                              : border,
                        ),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
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
        color: AppColors.resolve(context, AppColors.primaryBlue),
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
    final surface = AppColors.resolve(context, Colors.white);
    final border = AppColors.resolve(context, AppColors.inputBorder);
    final primary = AppColors.resolve(context, AppColors.primaryBlue);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _AssistantAvatar(size: 32),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.fromBorderSide(BorderSide(color: border)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: primary,
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
