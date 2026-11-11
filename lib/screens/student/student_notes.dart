import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/personal_note_service.dart';

Color _notesBlue(BuildContext context) =>
    AppColors.resolve(context, AppColors.primaryBlue);
Color _notesInk(BuildContext context) =>
    AppColors.resolve(context, AppColors.darkText);
Color _notesMuted(BuildContext context) =>
    AppColors.resolve(context, AppColors.secondaryText);
Color _notesSurface(BuildContext context) =>
    AppColors.resolve(context, Colors.white);
Color _notesBorder(BuildContext context) =>
    AppColors.resolve(context, AppColors.inputBorder);

String personalNoteDate(DateTime? value) {
  if (value == null) return 'Saving...';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = value.toLocal();
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

Future<bool> showPersonalNoteEditor(
  BuildContext context, {
  required PersonalNoteService service,
  PersonalStudentNote? note,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PersonalNoteEditorDialog(service: service, note: note),
      ) ??
      false;
}

Future<void> showPersonalNoteDetails(
  BuildContext context, {
  required PersonalStudentNote note,
  required PersonalNoteService service,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _notesSurface(dialogContext),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'My Note',
              style: TextStyle(
                color: _notesInk(dialogContext),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: TextStyle(
                  color: _notesInk(dialogContext),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Updated ${personalNoteDate(note.updatedAt)}',
                style: TextStyle(
                  color: _notesMuted(dialogContext),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              SelectableText(
                note.content,
                style: TextStyle(
                  color: _notesInk(dialogContext),
                  height: 1.65,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await showPersonalNoteEditor(context, service: service, note: note);
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: _notesBlue(dialogContext),
          ),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<bool> confirmPersonalNoteDelete(
  BuildContext context, {
  required PersonalStudentNote note,
  required PersonalNoteService service,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Delete this note?'),
      content: Text('"${note.title}" will be permanently removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.resolve(context, AppColors.error),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await service.deleteNote(note.id);
    return true;
  } on PersonalNoteException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

class StudentNotesDashboardSection extends StatefulWidget {
  const StudentNotesDashboardSection({super.key, required this.onOpenNotes});

  final VoidCallback onOpenNotes;

  @override
  State<StudentNotesDashboardSection> createState() =>
      _StudentNotesDashboardSectionState();
}

class _StudentNotesDashboardSectionState
    extends State<StudentNotesDashboardSection> {
  final _service = PersonalNoteService();
  final _pages = PageController();
  late Stream<List<PersonalStudentNote>> _notesStream;
  int _index = 0;
  Set<String> _previousIds = const {};
  List<String> _previousOrder = const [];
  String? _newestId;

  @override
  void initState() {
    super.initState();
    _notesStream = _service.watchMyNotes();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncNotes(List<PersonalStudentNote> notes) {
    final ids = notes.map((note) => note.id).toSet();
    final order = notes.map((note) => note.id).toList();
    final added = ids.difference(_previousIds);
    final currentId =
        _previousOrder.isNotEmpty && _index < _previousOrder.length
        ? _previousOrder[_index]
        : null;
    if (_previousIds.isNotEmpty && added.isNotEmpty) {
      _newestId = added.first;
      _index = notes.indexWhere((note) => note.id == _newestId);
    } else if (currentId != null) {
      final updatedIndex = order.indexOf(currentId);
      if (updatedIndex >= 0) _index = updatedIndex;
    }
    _previousIds = ids;
    _previousOrder = order;
    if (notes.isEmpty) {
      _index = 0;
    } else if (_index >= notes.length) {
      _index = notes.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || notes.isEmpty) return;
      _pages.jumpToPage(_index);
    });
  }

  void _go(int page) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      page,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (int index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _retry() {
    setState(() => _notesStream = _service.watchMyNotes());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonalStudentNote>>(
      stream: _notesStream,
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const <PersonalStudentNote>[];
        final order = notes.map((note) => note.id).toList();
        if (!_sameOrder(order, _previousOrder)) {
          _syncNotes(notes);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _notesBlue(context).withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.sticky_note_2_rounded,
                    color: _notesBlue(context),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'My Notes',
                    style: TextStyle(
                      color: _notesInk(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onOpenNotes,
                  child: Text(notes.isEmpty ? 'Create Note' : 'Manage Notes'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const _NotesLoading(key: ValueKey('loading'))
                  : snapshot.hasError
                  ? _NotesError(key: const ValueKey('error'), onRetry: _retry)
                  : notes.isEmpty
                  ? _NotesEmpty(
                      key: const ValueKey('empty'),
                      onCreate: widget.onOpenNotes,
                    )
                  : _buildCarousel(notes),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCarousel(List<PersonalStudentNote> notes) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      key: const ValueKey('notes'),
      children: [
        SizedBox(
          height: 238,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScrollConfiguration(
                behavior: const _NotesDragBehavior(),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: notes.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final highlight = note.id == _newestId;
                    return AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position:
                              Tween(
                                begin: const Offset(.04, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: child,
                        ),
                      ),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(note.id),
                        tween: Tween(begin: reduceMotion ? 1 : .96, end: 1),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 330),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: reduceMotion ? 1 : scale.clamp(0, 1),
                            child: child,
                          ),
                        ),
                        child: _DashboardNoteCard(
                          note: note,
                          highlighted: highlight,
                          onOpen: () => showPersonalNoteDetails(
                            context,
                            note: note,
                            service: _service,
                          ),
                          onEdit: () => showPersonalNoteEditor(
                            context,
                            service: _service,
                            note: note,
                          ),
                          onDelete: () => confirmPersonalNoteDelete(
                            context,
                            note: note,
                            service: _service,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (notes.length > 1 && _index > 0)
                Positioned(
                  left: 4,
                  child: _CarouselArrow(
                    icon: Icons.chevron_left_rounded,
                    label: 'Previous note',
                    onTap: () => _go(_index - 1),
                  ),
                ),
              if (notes.length > 1 && _index < notes.length - 1)
                Positioned(
                  right: 4,
                  child: _CarouselArrow(
                    icon: Icons.chevron_right_rounded,
                    label: 'Next note',
                    onTap: () => _go(_index + 1),
                  ),
                ),
            ],
          ),
        ),
        if (notes.length > 1) ...[
          const SizedBox(height: 10),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  notes.length,
                  (index) => AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _index
                          ? _notesBlue(context)
                          : _notesBorder(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardNoteCard extends StatelessWidget {
  const _DashboardNoteCard({
    required this.note,
    required this.highlighted,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalStudentNote note;
  final bool highlighted;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _notesBlue(context);
    final ink = _notesInk(context);
    final muted = _notesMuted(context);
    final surface = _notesSurface(context);
    final border = _notesBorder(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: highlighted ? accent : border,
                width: highlighted ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .22
                        : .08,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        highlighted ? 'New note' : 'Personal note',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Note actions',
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    note.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, height: 1.5, fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.update_rounded, size: 15, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      'Updated ${personalNoteDate(note.updatedAt)}',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      'Open',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalNoteEditorDialog extends StatefulWidget {
  const _PersonalNoteEditorDialog({required this.service, this.note});
  final PersonalNoteService service;
  final PersonalStudentNote? note;

  @override
  State<_PersonalNoteEditorDialog> createState() =>
      _PersonalNoteEditorDialogState();
}

class _PersonalNoteEditorDialogState extends State<_PersonalNoteEditorDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.note?.content ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.note == null) {
        await widget.service.createNote(
          title: _title.text,
          content: _content.text,
        );
      } else {
        await widget.service.updateNote(
          noteId: widget.note!.id,
          title: _title.text,
          content: _content.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PersonalNoteException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _notesSurface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.note == null ? 'Create a Personal Note' : 'Edit Note'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 150,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                minLines: 7,
                maxLines: 14,
                maxLength: 10000,
                decoration: const InputDecoration(
                  labelText: 'Write your note',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: AppColors.resolve(context, AppColors.error),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: _notesBlue(context)),
          icon: _saving
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save Note'),
        ),
      ],
    );
  }
}

class _NotesEmpty extends StatelessWidget {
  const _NotesEmpty({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
    decoration: BoxDecoration(
      color: _notesSurface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _notesBorder(context)),
    ),
    child: Column(
      children: [
        Icon(Icons.note_add_outlined, color: _notesBlue(context), size: 40),
        const SizedBox(height: 10),
        Text(
          'Keep your ideas close',
          style: TextStyle(
            color: _notesInk(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Create a private note and it will appear here automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _notesMuted(context), fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(backgroundColor: _notesBlue(context)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Your First Note'),
        ),
      ],
    ),
  );
}

class _NotesLoading extends StatelessWidget {
  const _NotesLoading({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 150,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

class _NotesError extends StatelessWidget {
  const _NotesError({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _notesSurface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _notesBorder(context)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: AppColors.resolve(context, AppColors.error),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Your notes could not be loaded.')),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon),
  );
}

class _NotesDragBehavior extends MaterialScrollBehavior {
  const _NotesDragBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
