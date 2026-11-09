import '../shared/aligned_page_app_bar.dart';
import '../shared/page_loading_state.dart';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import 'instructor_ui.dart';

/// A common frame for focused teaching tasks, separate from the main navigation.
class InstructorTaskScaffold extends StatelessWidget {
  const InstructorTaskScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.contextLabel,
    this.actions = const [],
    this.footer,
    this.busy = false,
    this.highlightHeading = false,
    this.loading = false,
  });
  final String title, subtitle;
  final String? contextLabel;
  final Widget body;
  final List<Widget> actions;
  final Widget? footer;
  final bool busy;
  final bool highlightHeading;
  final bool loading;
  static ThemeData taskTheme(BuildContext context) {
    final base = InstructorUi.theme(context);
    const label = WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(textStyle: label),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(textStyle: label),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(textStyle: label),
      ),
    );
  }

  static EdgeInsets paddingOf(
    BuildContext context, {
    double top = 8,
    double bottom = 28,
  }) {
    final inset = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return EdgeInsets.fromLTRB(inset, top, inset, bottom);
  }

  @override
  Widget build(BuildContext context) => loading
      ? const PageLoadingState()
      : PopScope(
          canPop: !busy,
          child: Theme(
            data: taskTheme(context),
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AlignedPageAppBar(
                maxWidth: 1080,
                inset: paddingOf(context).left,
                child: AppBar(
                  toolbarHeight: 48,
                  leadingWidth: 48,
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    tooltip: 'Back',
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 21),
                  ),
                  actions: actions,
                ),
              ),
              body: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: WorkspaceScrollingBody(
                      header: Padding(
                        padding: paddingOf(context, top: 12, bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (contextLabel?.trim().isNotEmpty == true) ...[
                              InstructorContextLabel(label: contextLabel!),
                              const SizedBox(height: 14),
                            ],
                            Container(
                              key: highlightHeading
                                  ? const ValueKey('selected-module-heading')
                                  : null,
                              padding: highlightHeading
                                  ? const EdgeInsets.all(18)
                                  : EdgeInsets.zero,
                              decoration: highlightHeading
                                  ? BoxDecoration(
                                      color: AppColors.resolve(
                                        context,
                                        AppColors.link,
                                      ).withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.resolve(
                                          context,
                                          AppColors.link,
                                        ).withValues(alpha: .35),
                                      ),
                                    )
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (highlightHeading) ...[
                                    const InstructorContextLabel(
                                      label: 'Selected module',
                                      icon: Icons.check_circle_outline_rounded,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  WorkspaceHeading(
                                    title: title,
                                    subtitle: subtitle,
                                    eyebrow: '',
                                    showEyebrow: false,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      body: body,
                    ),
                  ),
                ),
              ),
              bottomNavigationBar: footer,
            ),
          ),
        );
}

class InstructorTaskActions extends StatelessWidget {
  const InstructorTaskActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: InstructorTaskScaffold.paddingOf(
              context,
              top: 12,
              bottom: 14,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final stack =
                    box.maxWidth < 380 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                return stack
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            children[i],
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: children[i]),
                          ],
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class InstructorFormSection extends StatelessWidget {
  const InstructorFormSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
            ),
            if (description?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class InstructorFormColumns extends StatelessWidget {
  const InstructorFormColumns({
    super.key,
    required this.primary,
    required this.secondary,
  });
  final Widget primary, secondary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 880 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 20), secondary],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: primary),
          const SizedBox(width: 20),
          Expanded(flex: 4, child: secondary),
        ],
      );
    },
  );
}

class InstructorContextLabel extends StatelessWidget {
  const InstructorContextLabel({
    super.key,
    required this.label,
    this.icon = Icons.menu_book_outlined,
  });
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(
          icon,
          size: 17,
          color: AppColors.resolve(context, AppColors.link),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class InstructorTaskNotice extends StatelessWidget {
  const InstructorTaskNotice({
    super.key,
    required this.text,
    this.error = false,
  });
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = error
        ? colors.error
        : AppColors.resolve(context, AppColors.link);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: error ? colors.error : colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
