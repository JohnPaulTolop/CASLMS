import 'package:flutter/material.dart';

import '../../services/assistant_attachment_service.dart';

/// One compact mode switch replaces the separate title, banner and chips.
class AssistantConversationToolbar extends StatelessWidget {
  const AssistantConversationToolbar({
    super.key,
    required this.studyHelp,
    required this.instructor,
    required this.enabled,
    required this.onModeChanged,
    required this.onNew,
    required this.onInfo,
    this.onRefresh,
    this.onBack,
    this.onHistory,
  });
  final bool studyHelp, instructor, enabled;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onNew, onInfo;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onHistory;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null)
        IconButton(
          tooltip: 'Back to course',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      Expanded(
        child: PopupMenuButton<String>(
          tooltip: 'Assistant mode',
          enabled: enabled,
          onSelected: (value) =>
              value == 'help' ? onInfo() : onModeChanged(value == 'study'),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'study', child: Text('Study help')),
            PopupMenuItem(
              value: 'records',
              child: Text(instructor ? 'Student records' : 'My records'),
            ),
            const PopupMenuItem(value: 'help', child: Text('Assistant help')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    studyHelp
                        ? 'AI Assistant'
                        : instructor
                        ? 'Student records'
                        : 'My records',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
      if (onHistory != null)
        IconButton(
          tooltip: 'Chat history',
          onPressed: enabled ? onHistory : null,
          icon: const Icon(Icons.history_rounded, size: 21),
        ),
      if (MediaQuery.sizeOf(context).width >= 700)
        IconButton(
          tooltip: 'Assistant help',
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline_rounded, size: 20),
        ),
      if (onRefresh != null)
        IconButton(
          tooltip: 'Refresh records and clear chat',
          onPressed: enabled ? onRefresh : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      IconButton(
        tooltip: 'New conversation',
        onPressed: enabled ? onNew : null,
        icon: const Icon(Icons.edit_square, size: 21),
      ),
    ],
  );
}

class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.ready,
    required this.busy,
    required this.studyHelp,
    required this.attachments,
    required this.onAttach,
    required this.onLink,
    required this.onRemove,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool ready, busy, studyHelp;
  final List<AssistantAttachment> attachments;
  final VoidCallback onAttach, onLink, onSend;
  final ValueChanged<int> onRemove;
  Widget _field(BuildContext context, bool compact) => TextField(
    key: const ValueKey('assistant-question'),
    controller: controller,
    enabled: ready,
    minLines: 1,
    maxLines: compact ? 1 : 4,
    maxLength: 1500,
    textInputAction: compact ? TextInputAction.send : TextInputAction.newline,
    onSubmitted: compact
        ? (_) {
            if (!busy && ready) onSend();
          }
        : null,
    decoration: InputDecoration(
      hintText: studyHelp
          ? 'Ask about your coursework…'
          : 'Ask about these records…',
      counterText: '',
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    ),
  );

  Widget _send() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) => IconButton.filled(
      tooltip: 'Send question',
      onPressed: busy || !ready || value.text.trim().isEmpty ? null : onSend,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_upward_rounded, size: 22),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      key: const ValueKey('assistant-composer'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attachments.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => InputChip(
                  tooltip: attachments[index].isLink
                      ? 'Reference link; webpage content is not fetched'
                      : 'Relevant text excerpts shared with your question',
                  avatar: Icon(
                    attachments[index].isLink
                        ? Icons.link_rounded
                        : Icons.description_outlined,
                    size: 16,
                  ),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      attachments[index].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: busy ? null : () => onRemove(index),
                ),
              ),
            ),
          if (compact)
            Row(
              children: [
                if (studyHelp)
                  PopupMenuButton<String>(
                    tooltip: 'Add attachment or link',
                    enabled: !busy && attachments.length < 3,
                    icon: const Icon(Icons.add_rounded),
                    onSelected: (value) =>
                        value == 'file' ? onAttach() : onLink(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'file',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.attach_file_rounded),
                          title: Text('File or module material'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'link',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.link_rounded),
                          title: Text('Reference link'),
                        ),
                      ),
                    ],
                  ),
                Expanded(child: _field(context, true)),
                _send(),
              ],
            )
          else ...[
            _field(context, false),
            Row(
              children: [
                if (studyHelp) ...[
                  IconButton(
                    tooltip: 'Attach file or module material',
                    onPressed: busy || attachments.length >= 3
                        ? null
                        : onAttach,
                    icon: const Icon(Icons.attach_file_rounded, size: 21),
                  ),
                  IconButton(
                    tooltip: 'Add reference link',
                    onPressed: busy || attachments.length >= 3 ? null : onLink,
                    icon: const Icon(Icons.link_rounded, size: 23),
                  ),
                ],
                const Spacer(),
                _send(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
