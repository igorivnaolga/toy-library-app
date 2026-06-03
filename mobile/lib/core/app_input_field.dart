import "package:flutter/material.dart";

import "app_text_styles.dart";
import "app_theme.dart";

TextStyle fieldTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium!.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );
}

TextStyle fieldPlaceholderStyle(BuildContext context) {
  final theme = Theme.of(context);
  return fieldTextStyle(context).copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: kTextMutedAlpha),
  );
}

TextStyle _fieldLabelStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: theme.colorScheme.onSurface.withValues(alpha: kTextSubtleAlpha),
  );
}

TextStyle fieldHelperStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall!.copyWith(
    fontWeight: FontWeight.w500,
    color: theme.colorScheme.onSurface.withValues(alpha: kTextMutedAlpha),
    height: 1.3,
  );
}

Color fieldCursorColor(BuildContext context) => kBrandYellow;

InputDecoration _inputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  String? helperText,
  String? errorText,
  TextStyle? helperStyle,
  int? helperMaxLines,
  Widget? suffixIcon,
  Widget? prefixIcon,
  Color? fillColor,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final inputTheme = theme.inputDecorationTheme;
  final muted = colors.onSurface.withValues(alpha: kTextMutedAlpha);

  final hintBase = inputTheme.hintStyle ?? theme.textTheme.bodyMedium;
  final hintStyle = hintBase?.copyWith(
    color: muted,
    fontWeight: FontWeight.w500,
  );

  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    helperText: helperText,
    errorText: errorText,
    hintStyle: hintStyle,
    labelStyle: _fieldLabelStyle(context),
    floatingLabelStyle: _fieldLabelStyle(context).copyWith(
      color: kBrandYellow,
    ),
    helperStyle: helperStyle ?? fieldHelperStyle(context),
    helperMaxLines: helperMaxLines ?? (helperText != null ? 3 : null),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: inputTheme.isDense,
    filled: inputTheme.filled,
    fillColor: fillColor ?? inputTheme.fillColor,
    contentPadding: inputTheme.contentPadding,
    border: inputTheme.border,
    enabledBorder: inputTheme.enabledBorder,
    focusedBorder: inputTheme.focusedBorder,
    disabledBorder: inputTheme.disabledBorder,
    errorBorder: inputTheme.errorBorder,
    focusedErrorBorder: inputTheme.focusedErrorBorder,
  );
}

InputDecoration labeledInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  TextStyle? helperStyle,
  int? helperMaxLines,
  Widget? suffixIcon,
  Widget? prefixIcon,
  Color? fillColor,
}) {
  return _inputDecoration(
    context,
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    helperStyle: helperStyle,
    helperMaxLines: helperMaxLines,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    fillColor: fillColor,
  );
}

InputDecoration searchInputDecoration(
  BuildContext context, {
  required String hintText,
  Widget? suffixIcon,
  bool showSearchIcon = true,
}) {
  final muted = Theme.of(context)
      .colorScheme
      .onSurface
      .withValues(alpha: kTextMutedAlpha);

  return _inputDecoration(
    context,
    hintText: hintText,
    suffixIcon: suffixIcon,
    prefixIcon: showSearchIcon
        ? Icon(Icons.search, color: muted, size: 22)
        : null,
  );
}

Widget? searchClearSuffix(
  BuildContext context, {
  required bool visible,
  required VoidCallback onClear,
}) {
  if (!visible) return null;
  final muted =
      Theme.of(context).colorScheme.onSurface.withValues(alpha: kTextMutedAlpha);
  return IconButton(
    icon: Icon(Icons.clear, color: muted),
    onPressed: onClear,
    tooltip: "Clear search",
  );
}

TextStyle searchFieldTextStyle(BuildContext context) => fieldTextStyle(context);

Widget searchLoadingSuffix() {
  return const Padding(
    padding: EdgeInsets.all(12),
    child: SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
