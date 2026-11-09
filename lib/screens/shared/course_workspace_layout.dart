import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'course_banner.dart';
import 'workspace_shell.dart';
import 'workspace_widgets.dart';

/// Shared course framing. Each role retains its own data and actions.
class CourseWorkspaceLayout extends StatelessWidget {
  const CourseWorkspaceLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.pages,
    required this.onRefresh,
    this.actions = const [],
    this.toolbarActions = const [],
    this.eyebrow = 'COURSE TEACHING WORKSPACE',
    this.initialIndex = 0,
    this.color = AppColors.primaryBlue,
  });

  final String title, subtitle, eyebrow;
  final List<String> labels;
  final List<Widget> pages, actions, toolbarActions;
  final Future<void> Function() onRefresh;
  final int initialIndex;
  final Color color;

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 4,
    double bottom = 28,
  }) {
    final inset = workspaceInset(
      MediaQuery.sizeOf(context).width.clamp(0, 1450),
    );
    return EdgeInsets.fromLTRB(inset, top, inset, bottom);
  }

  static ButtonStyle actionStyle(BuildContext context) {
    final link = AppColors.resolve(context, AppColors.link);
    return FilledButton.styleFrom(
      backgroundColor: link.withValues(alpha: .08),
      foregroundColor: link,
      elevation: 0,
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      side: BorderSide(color: link.withValues(alpha: .18)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: labels.length,
    initialIndex: initialIndex,
    animationDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: LayoutBuilder(
              builder: (context, box) {
                final inset = workspaceInset(box.maxWidth);
                final scrollable =
                    box.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final tabs = Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: .5),
                    ),
                  ),
                  child: TabBar(
                    isScrollable: scrollable,
                    tabAlignment: scrollable
                        ? TabAlignment.start
                        : TabAlignment.fill,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.resolve(
                        context,
                        AppColors.link,
                      ).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    labelColor: AppColors.resolve(context, AppColors.link),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    unselectedLabelColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: [
                      for (final label in labels) Tab(height: 40, text: label),
                    ],
                  ),
                );
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            inset,
                            box.maxWidth < 700 ? 0 : 12,
                            inset,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  if (box.maxWidth >= 700)
                                    IconButton(
                                      tooltip: 'Back',
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    ),
                                  const Spacer(),
                                  ...toolbarActions,
                                  if (box.maxWidth >= 700)
                                    IconButton(
                                      tooltip: 'Refresh course content',
                                      onPressed: onRefresh,
                                      icon: const Icon(Icons.refresh_rounded),
                                    ),
                                ],
                              ),
                              if (box.maxWidth >= 700 ||
                                  toolbarActions.isNotEmpty)
                                const SizedBox(height: 4),
                              CourseBanner(
                                color: color,
                                child: WorkspaceHeading(
                                  title: title,
                                  subtitle: subtitle,
                                  eyebrow: eyebrow,
                                ),
                              ),
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    filledButtonTheme: FilledButtonThemeData(
                                      style: actionStyle(context),
                                    ),
                                    outlinedButtonTheme:
                                        OutlinedButtonThemeData(
                                          style: actionStyle(context),
                                        ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: actionStyle(context),
                                    ),
                                  ),
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: actions,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: LayoutBuilder(
                      builder: (context, viewport) => Column(
                        children: [
                          SizedBox(
                            height: viewport.maxHeight < 56
                                ? viewport.maxHeight
                                : 56,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: 56,
                                maxHeight: 56,
                                child: ColoredBox(
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      inset,
                                      0,
                                      inset,
                                      8,
                                    ),
                                    child: tabs,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: TabBarView(children: pages)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
