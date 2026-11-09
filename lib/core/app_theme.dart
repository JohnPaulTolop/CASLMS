import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The approved CASLMS workspace theme, shared by every role and route.
abstract final class AppTheme {
  static const double progressBarHeight = 14;

  static final ThemeData light = _buildLight();
  static final ThemeData dark = _buildDark();

  static ThemeData _buildLight() {
    const blue = AppColors.primaryBlue;
    const ink = AppColors.darkText;
    const muted = AppColors.secondaryText;
    const line = AppColors.inputBorder;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    );
    final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
    final text = base.textTheme
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          headlineLarge: const TextStyle(
            color: ink,
            fontSize: 35,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
            height: 1.15,
          ),
          headlineSmall: const TextStyle(
            color: ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
          titleLarge: const TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.4,
          ),
          titleMedium: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          bodyLarge: const TextStyle(color: ink, fontSize: 14, height: 1.5),
          bodyMedium: const TextStyle(color: ink, fontSize: 14, height: 1.5),
          bodySmall: const TextStyle(color: muted, fontSize: 12, height: 1.5),
        );
    final filled = FilledButton.styleFrom(
      backgroundColor: blue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      minimumSize: const Size(48, 48),
      shape: shape,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
        primary: blue,
        onPrimary: Colors.white,
        secondary: AppColors.purple,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: line,
        outlineVariant: line,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: AppColors.background,
        surfaceContainer: AppColors.blueTint,
        error: AppColors.error,
        surfaceTint: Colors.transparent,
      ),
      textTheme: text,
      iconTheme: const IconThemeData(color: muted, size: 21),
      dividerColor: line,
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filled),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: filled.copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.link,
          side: const BorderSide(color: line),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.link,
          shape: shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: blue, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: text.bodySmall,
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        errorMaxLines: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.background),
        dataRowColor: const WidgetStatePropertyAll(Colors.white),
        headingTextStyle: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        dataTextStyle: text.bodyMedium,
        dividerThickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.blueTint,
        side: const BorderSide(color: line),
        labelStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: blue,
        linearTrackColor: AppColors.blueTint,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      focusColor: blue.withValues(alpha: .16),
      hoverColor: blue.withValues(alpha: .04),
    );
  }

  static ThemeData _buildDark() {
    // Keep typography and component styles compatible during theme animation.
    final base = light.copyWith(
      brightness: Brightness.dark,
      canvasColor: DarkAppColors.surface,
      primaryColor: DarkAppColors.primaryBlue,
      hintColor: DarkAppColors.secondaryText,
      disabledColor: DarkAppColors.secondaryText.withValues(alpha: .38),
      unselectedWidgetColor: DarkAppColors.secondaryText,
      focusColor: DarkAppColors.primaryBlue.withValues(alpha: .16),
      hoverColor: DarkAppColors.primaryBlue.withValues(alpha: .08),
      highlightColor: DarkAppColors.primaryBlue.withValues(alpha: .10),
      splashColor: DarkAppColors.primaryBlue.withValues(alpha: .12),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: DarkAppColors.primaryBlue,
        selectionColor: DarkAppColors.primaryBlue.withValues(alpha: .28),
        selectionHandleColor: DarkAppColors.primaryBlue,
      ),
      scaffoldBackgroundColor: DarkAppColors.background,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: DarkAppColors.primaryBlue,
            brightness: Brightness.dark,
          ).copyWith(
            primary: DarkAppColors.primaryBlue,
            onPrimary: DarkAppColors.background,
            secondary: DarkAppColors.purple,
            surface: DarkAppColors.surface,
            onSurface: DarkAppColors.darkText,
            onSurfaceVariant: DarkAppColors.secondaryText,
            outline: DarkAppColors.inputBorder,
            outlineVariant: DarkAppColors.inputBorder,
            surfaceContainerLowest: DarkAppColors.surface,
            surfaceContainerLow: DarkAppColors.background,
            surfaceContainer: DarkAppColors.blueTint,
            error: DarkAppColors.error,
            surfaceTint: Colors.transparent,
          ),
      dividerColor: DarkAppColors.inputBorder,
      dividerTheme: const DividerThemeData(
        color: DarkAppColors.inputBorder,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: DarkAppColors.secondaryText,
        size: 21,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkAppColors.background,
        foregroundColor: DarkAppColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: DarkAppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DarkAppColors.inputBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkAppColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkAppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DarkAppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: DarkAppColors.primaryBlue,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(color: DarkAppColors.secondaryText),
        labelStyle: const TextStyle(color: DarkAppColors.secondaryText),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DarkAppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DarkAppColors.inputBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DarkAppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: DarkAppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DarkAppColors.inputBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: DarkAppColors.background,
        selectedColor: DarkAppColors.blueTint,
        side: const BorderSide(color: DarkAppColors.inputBorder),
        labelStyle: const TextStyle(color: DarkAppColors.secondaryText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: DarkAppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DarkAppColors.primaryBlue,
        linearTrackColor: DarkAppColors.blueTint,
      ),
    );
    final text = base.textTheme.apply(
      bodyColor: DarkAppColors.darkText,
      displayColor: DarkAppColors.darkText,
    );
    return base.copyWith(
      textTheme: text,
      // Primary calls to action retain the shared blue-and-white brand style.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarkAppColors.link,
          side: const BorderSide(color: DarkAppColors.inputBorder),
        ).merge(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: DarkAppColors.link)
            .merge(base.textButtonTheme.style),
      ),
      dataTableTheme: base.dataTableTheme.copyWith(
        headingRowColor: const WidgetStatePropertyAll(DarkAppColors.background),
        dataRowColor: const WidgetStatePropertyAll(DarkAppColors.surface),
        headingTextStyle: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        dataTextStyle: text.bodyMedium,
      ),
    );
  }
}
