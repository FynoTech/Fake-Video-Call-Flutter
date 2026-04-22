import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.themeSeed,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(surface: AppColors.white),
      scaffoldBackgroundColor: AppColors.white,
      canvasColor: AppColors.white,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppColors.fontFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: AppColors.fontFamily,
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontFamily: AppColors.fontFamily,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
