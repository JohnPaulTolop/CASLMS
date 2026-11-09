import '../../core/app_colors.dart';

import 'package:flutter/material.dart';

import '../shared/workspace_widgets.dart';
import '../shared/page_loading_state.dart';

abstract final class InstructorUi {
  static const Color primary = AppColors.primaryBlue;
  static const Color primaryDark = AppColors.primaryBlue;
  static const Color accent = AppColors.green;
  static const Color background = AppColors.background;
  static const Color surface = Colors.white;
  static const Color text = AppColors.darkText;
  static const Color muted = AppColors.secondaryText;
  static const Color border = AppColors.inputBorder;
  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final colors = base.colorScheme;
    final foreground = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.disabled)
          ? colors.onSurface.withValues(alpha: .38)
          : AppColors.resolve(context, AppColors.link),
    );
    return base.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: foreground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: foreground,
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
    );
  }
}

Widget instructorScaffold({
  required BuildContext context,
  Color? backgroundColor,
  PreferredSizeWidget? appBar,
  Widget? body,
  Widget? floatingActionButton,
  FloatingActionButtonLocation? floatingActionButtonLocation,
  Widget? bottomNavigationBar,
  Widget? bottomSheet,
  bool? resizeToAvoidBottomInset,
  bool primary = true,
  bool extendBody = false,
  bool extendBodyBehindAppBar = false,
  String? title,
  String subtitle = '',
  List<Widget>? actions,
  bool loading = false,
}) {
  if (loading) return const PageLoadingState();
  final page = title == null
      ? body
      : WorkspaceScrollingBody(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: WorkspaceHeading(
              title: title,
              subtitle: subtitle,
              eyebrow: '',
              showEyebrow: false,
              inlineActions: true,
              actions: actions,
            ),
          ),
          body: body ?? const SizedBox.shrink(),
        );
  return Theme(
    data: InstructorUi.theme(context),
    child: Scaffold(
      backgroundColor: AppColors.resolve(
        context,
        backgroundColor ?? InstructorUi.background,
      ),
      appBar: title == null ? appBar : null,
      body: title == null
          ? page
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: page,
              ),
            ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    ),
  );
}
