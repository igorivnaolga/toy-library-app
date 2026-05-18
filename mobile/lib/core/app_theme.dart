import "package:flutter/material.dart";

/// Church Corner Toy Library brand yellow (from organisation letterhead).
const Color kBrandYellow = Color(0xFFFDC435);
const Color kBrandOnYellow = Color(0xFF1A1A1A);

/// Light theme aligned with the toy library letterhead (yellow banner, dark type).
ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kBrandYellow,
    brightness: Brightness.light,
  );
  final scheme = base.copyWith(
    primary: kBrandYellow,
    onPrimary: kBrandOnYellow,
    primaryContainer: const Color(0xFFFFE8A3),
    onPrimaryContainer: kBrandOnYellow,
    secondary: const Color(0xFF5C4A00),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: kBrandOnYellow,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: scheme.onPrimary),
      actionsIconTheme: IconThemeData(color: scheme.onPrimary),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onPrimary,
      unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.65),
      indicatorColor: scheme.onPrimary,
      dividerColor: scheme.onPrimary.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      tabAlignment: TabAlignment.fill,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.onSurface,
    ),
  );
}
