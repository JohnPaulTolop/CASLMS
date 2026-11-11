import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/personal_note_service.dart';
import 'student_notes.dart';

class StudentNotesScreen extends StatefulWidget {
  const StudentNotesScreen({super.key});

  @override
  State<StudentNotesScreen> createState() => _StudentNotesScreenState();
}

class _StudentNotesScreenState extends State<StudentNotesScreen> {
  Color get _blue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get _ink => AppColors.resolve(context, AppColors.darkText);
  Color get _muted => AppColors.resolve(context, AppColors.secondaryText);
  Color get _surface => AppColors.resolve(context, Colors.white);
  Color get _border => AppColors.resolve(context, AppColors.inputBorder);

  final _service = PersonalNoteService();
  late Stream<List<PersonalStudentNote>> _notesStream;

  @override
  void initState() {
    super.initState();
    _notesStream = _service.watchMyNotes();
  }

  void _retry() {
    setState(() => _notesStream = _service.watchMyNotes());
  }

  Future<void> _create() async {
    final saved = await showPersonalNoteEditor(context, service: _service);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your private note was saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.resolve(context, AppColors.background),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 820;
            return Stack(
              children: [
                const Positioned.fill(child: _NotesPageBackdrop()),
                StreamBuilder<List<PersonalStudentNote>>(
                  stream: _notesStream,
                  builder: (context, snapshot) {
                    final notes =
                        snapshot.data ?? const <PersonalStudentNote>[];
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 42 : 18,
                            desktop ? 30 : 18,
                            desktop ? 42 : 18,
                            16,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1120,
                                ),
                                child: _header(notes.length, desktop),
                              ),
                            ),
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (snapshot.hasError)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ErrorState(onRetry: _retry),
                          )
                        else if (notes.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(onCreate: _create),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              desktop ? 42 : 18,
                              10,
                              desktop ? 42 : 18,
                              34,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1120,
                                  ),
                                  child: _buildNotes(notes, desktop),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: _blue,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _header(int count, bool desktop) {
    return Container(
      padding: EdgeInsets.all(desktop ? 26 : 20),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .22
                  : .08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: desktop ? 58 : 50,
            height: desktop ? 58 : 50,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.sticky_note_2_rounded, color: _blue, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Notes',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 1
                      ? '1 private note saved to your account'
                      : '$count private notes saved to your account',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (desktop)
            FilledButton.icon(
              onPressed: _create,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Note'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotes(List<PersonalStudentNote> notes, bool desktop) {
    if (!desktop) {
      return Column(
        children: [
          for (final note in notes) ...[
            _PersonalNoteTile(note: note, service: _service),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.18,
      ),
      itemCount: notes.length,
      itemBuilder: (_, index) =>
          _PersonalNoteTile(note: notes[index], service: _service),
    );
  }
}

class _PersonalNoteTile extends StatelessWidget {
  const _PersonalNoteTile({required this.note, required this.service});
  final PersonalStudentNote note;
  final PersonalNoteService service;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.resolve(context, AppColors.primaryBlue);
    final ink = AppColors.resolve(context, AppColors.darkText);
    final muted = AppColors.resolve(context, AppColors.secondaryText);
    final surface = AppColors.resolve(context, Colors.white);
    final border = AppColors.resolve(context, AppColors.inputBorder);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            showPersonalNoteDetails(context, note: note, service: service),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? .2
                      : .07,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.resolve(context, AppColors.blueTint),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.notes_rounded, color: accent, size: 19),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    onSelected: (value) {
                      if (value == 'edit') {
                        showPersonalNoteEditor(
                          context,
                          service: service,
                          note: note,
                        );
                      } else if (value == 'delete') {
                        confirmPersonalNoteDelete(
                          context,
                          note: note,
                          service: service,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                ),
              ),
              Divider(color: border),
              Text(
                'Updated ${personalNoteDate(note.updatedAt)}',
                style: TextStyle(color: muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 62,
            color: AppColors.resolve(context, AppColors.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'No personal notes yet',
            style: TextStyle(
              color: AppColors.resolve(context, AppColors.darkText),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Your notes are private and only visible in your student account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.resolve(context, AppColors.secondaryText),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.resolve(
                context,
                AppColors.primaryBlue,
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Your First Note'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: AppColors.resolve(context, AppColors.error),
        ),
        const SizedBox(height: 12),
        const Text('Unable to load your private notes.'),
        TextButton(onPressed: onRetry, child: const Text('Try Again')),
      ],
    ),
  );
}

class _NotesPageBackdrop extends StatelessWidget {
  const _NotesPageBackdrop();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  DarkAppColors.background,
                  DarkAppColors.noticeboard,
                  DarkAppColors.surface,
                ]
              : const [Color(0xFFEAF2FF), Color(0xFFDCE8FF), Color(0xFFF5F7FF)],
        ),
      ),
    );
  }
}
