import "package:flutter/material.dart";

const Color kBrandYellow = Color(0xFFFDC435);
const Color kBrandOnYellow = Color(0xFF1A1A1A);

const Color kMembershipTierCardBg = Color(0xFFFFF6E0);

const Color kStatusOnLoanBg = Color(0xFFFFE0B2);
const Color kStatusOnLoanFg = Color(0xFFE65100);

const Color kModalSurface = Color(0xFFF6F4F0);

/// Soft tint for grouped list date headers (bookings, loans).
const Color kGroupHeaderBackground = Color(0xFFFFF8E8);
const Color kGroupHeaderBorder = Color(0xFFF5D78E);

/// Shared height for side-by-side modal actions (Cancel + confirm).
const double kModalActionButtonHeight = 44;

/// Yellow-outline secondary action used for Cancel / dismiss in modals.
ButtonStyle brandOutlinedButtonStyle({Color? backgroundColor}) {
  return OutlinedButton.styleFrom(
    foregroundColor: kBrandOnYellow,
    backgroundColor: backgroundColor ?? kModalSurface,
    disabledForegroundColor: kBrandOnYellow.withValues(alpha: 0.45),
    disabledBackgroundColor: backgroundColor ?? kModalSurface,
    surfaceTintColor: Colors.transparent,
    side: const BorderSide(color: kBrandYellow, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    minimumSize: const Size.fromHeight(kModalActionButtonHeight),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    ),
  );
}

ButtonStyle brandFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: kBrandYellow,
    foregroundColor: kBrandOnYellow,
    disabledBackgroundColor: kBrandYellow.withValues(alpha: 0.55),
    disabledForegroundColor: kBrandOnYellow.withValues(alpha: 0.7),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    minimumSize: const Size.fromHeight(kModalActionButtonHeight),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    ),
  );
}

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
    surfaceContainerHighest: const Color(0xFFF3F3F3),
    surfaceContainerHigh: kModalSurface,
    surfaceContainerLowest: const Color(0xFFFAFAFA),
    outlineVariant: const Color(0xFFE0E0E0),
  );

  final baseText = ThemeData(useMaterial3: true).textTheme;
  final textTheme = baseText
      .copyWith(
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 16),
        bodySmall: baseText.bodySmall?.copyWith(fontSize: 13),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurface),
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.45),
      indicatorColor: kBrandYellow,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.6),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      tabAlignment: TabAlignment.fill,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface.withValues(alpha: 0.62),
      ),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: kBrandYellow,
      ),
      helperStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface.withValues(alpha: 0.62),
        height: 1.3,
      ),
      errorStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.error,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBrandYellow, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: brandFilledButtonStyle(),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: brandOutlinedButtonStyle(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.onSurface,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kModalSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kModalSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
  );
}
