import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Resolves shared design tokens at render time, including model accents.
  static Color resolve(BuildContext context, Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    return _darkTokens[color] ?? color;
  }

  static final _darkTokens = <Color, Color>{
    Colors.white: DarkAppColors.surface,
    LightAppColors.link: DarkAppColors.link,
    LightAppColors.primaryBlue: DarkAppColors.primaryBlue,
    LightAppColors.darkText: DarkAppColors.darkText,
    LightAppColors.secondaryText: DarkAppColors.secondaryText,
    LightAppColors.background: DarkAppColors.background,
    LightAppColors.inputBorder: DarkAppColors.inputBorder,
    LightAppColors.blueTint: DarkAppColors.blueTint,
    LightAppColors.noticeboard: DarkAppColors.noticeboard,
    LightAppColors.purple: DarkAppColors.purple,
    LightAppColors.purpleTint: DarkAppColors.purpleTint,
    LightAppColors.green: DarkAppColors.green,
    LightAppColors.greenTint: DarkAppColors.greenTint,
    LightAppColors.amber: DarkAppColors.amber,
    LightAppColors.amberTint: DarkAppColors.amberTint,
    LightAppColors.error: DarkAppColors.error,
  };

  static const Color primaryBlue = LightAppColors.primaryBlue;
  static const Color link = LightAppColors.link;
  static const Color darkText = LightAppColors.darkText;
  static const Color secondaryText = LightAppColors.secondaryText;
  static const Color background = LightAppColors.background;
  static const Color inputBorder = LightAppColors.inputBorder;
  static const Color blueTint = LightAppColors.blueTint;
  static const Color noticeboard = LightAppColors.noticeboard;
  static const Color purple = LightAppColors.purple;
  static const Color purpleTint = LightAppColors.purpleTint;
  static const Color green = LightAppColors.green;
  static const Color greenTint = LightAppColors.greenTint;
  static const Color amber = LightAppColors.amber;
  static const Color amberTint = LightAppColors.amberTint;
  static const Color error = LightAppColors.error;
}

abstract final class LightAppColors {
  static const Color link = Color(0xFF5267A3);
  static const Color primaryBlue = Color(0xFF4263EB);
  static const Color darkText = Color(0xFF17243F);
  static const Color secondaryText = Color(0xFF7A8498);
  static const Color background = Color(0xFFF8FAFD);
  static const Color inputBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFE9EDF5);
  static const Color blueTint = Color(0xFFEDF2FF);
  static const Color noticeboard = Color(0xFFF0F4FC);
  static const Color purple = Color(0xFF9472D4);
  static const Color purpleTint = Color(0xFFF3EEFB);
  static const Color green = Color(0xFF3B9685);
  static const Color greenTint = Color(0xFFEAF6F2);
  static const Color amber = Color(0xFFB68A46);
  static const Color amberTint = Color(0xFFFAF3E6);
  static const Color error = Color(0xFFB42332);
}

abstract final class DarkAppColors {
  static const Color link = Color(0xFFA3B3DF);
  static const Color primaryBlue = Color(0xFF8EA7FF);
  static const Color darkText = Color(0xFFF1F4FA);
  static const Color secondaryText = Color(0xFFB5BDCC);
  static const Color background = Color(0xFF111827);
  static const Color inputBackground = Color(0xFF1F2937);
  static const Color surface = Color(0xFF1F2937);
  static const Color inputBorder = Color(0xFF374151);
  static const Color blueTint = Color(0xFF25345F);
  static const Color noticeboard = Color(0xFF1A2433);
  static const Color purple = Color(0xFFB9A1F0);
  static const Color purpleTint = Color(0xFF3A2B5E);
  static const Color green = Color(0xFF68C7B5);
  static const Color greenTint = Color(0xFF1F4A42);
  static const Color amber = Color(0xFFE0B77A);
  static const Color amberTint = Color(0xFF4A3B28);
  static const Color error = Color(0xFFFF8A9B);
}
