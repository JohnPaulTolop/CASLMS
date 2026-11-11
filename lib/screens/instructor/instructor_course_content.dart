import 'package:flutter/material.dart';

import '../shared/workspace_widgets.dart';
import '../shared/course_workspace_layout.dart';

/// Role-specific controls with the same module hierarchy as the learner view.
class InstructorCourseContent extends StatefulWidget {
  const InstructorCourseContent({
    super.key,
    required this.modules,
    required this.materials,
    required this.assessments,
    required this.onCreate,
    required this.onManage,
    required this.onMaterial,
    required this.onAssessment,
    this.sectionScoped = false,
  });
  final List<Map<String, dynamic>> modules, materials, assessments;
  final bool sectionScoped;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onManage, onAssessment;
  final void Function(
    Map<String, dynamic> module,
    Map<String, dynamic> material,
  )
  onMaterial;
  @override
  State<InstructorCourseContent> createState() =>
      _InstructorCourseContentState();
}

class _InstructorCourseContentState extends State<InstructorCourseContent>
    with AutomaticKeepAliveClientMixin {
  String _id(Map<String, dynamic> module) =>
      (module['moduleId'] ?? module['id'] ?? '').toString();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final list = ListView(
      key: const PageStorageKey('instructor-course-content'),
      padding: CourseWorkspaceLayout.pagePadding(
        context,
        bottom: mobile ? 100 : 28,
      ),
      children: [
        if (widget.sectionScoped) ...[
          Text(
            'Showing modules assigned to this section, including shared modules.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (!mobile)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              style: CourseWorkspaceLayout.actionStyle(context),
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add module'),
            ),
          ),
        if (!mobile) const SizedBox(height: 16),
        if (widget.modules.isEmpty)
          const WorkspaceEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No modules yet',
            message:
                'Create a module, then add learning materials and activities.',
          ),
        for (var index = 0; index < widget.modules.length; index++)
          _module(context, widget.modules[index], index),
      ],
    );
    return Stack(
      children: [
        Positioned.fill(child: list),
        if (mobile)
          Positioned(
            right: 20,
            bottom: 16,
            child: FloatingActionButton.small(
              key: const ValueKey('add-module-floating'),
              tooltip: 'Add module',
              onPressed: widget.onCreate,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              elevation: 1,
              child: const Icon(Icons.add_rounded),
            ),
          ),
      ],
    );
  }

  Widget _module(BuildContext context, Map<String, dynamic> module, int index) {
    final id = _id(module);
    final materialCount = widget.materials
        .where((row) => row['moduleId'] == id)
        .length;
    final activityCount = widget.assessments
        .where((row) => row['moduleId'] == id)
        .length;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: ValueKey('open-module-$id'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          onTap: () => widget.onManage(module),
          title: Text(
            (module['title'] ?? 'Untitled module').toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Module ${index + 1} • ${module['status'] ?? 'draft'}\n'
              '$materialCount materials • $activityCount activities',
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
