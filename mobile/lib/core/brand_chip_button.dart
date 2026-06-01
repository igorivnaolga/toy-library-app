import "package:flutter/material.dart";

import "app_theme.dart";

enum BrandChipButtonVariant { filled, outlined }

/// Shared width for booking list trailing chips (`Cancel`, `Cancelled`, etc.).
const double kBookingsChipWidth = 100;

/// Tappable chip for primary toy actions and booking controls.
class BrandChipButton extends StatelessWidget {
  const BrandChipButton({
    super.key,
    required this.label,
    this.onPressed,
    this.large = false,
    this.variant = BrandChipButtonVariant.filled,
    this.fixedWidth,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool large;
  final BrandChipButtonVariant variant;
  final double? fixedWidth;

  static ButtonStyle get _largeFilledStyle => FilledButton.styleFrom(
        backgroundColor: kBrandYellow,
        foregroundColor: kBrandOnYellow,
        disabledBackgroundColor: kBrandYellow.withValues(alpha: 0.55),
        disabledForegroundColor: kBrandOnYellow.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
      );

  static ButtonStyle get _largeOutlinedStyle =>
      brandOutlinedButtonStyle().copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (large) {
      final child = Text(
        label,
        style: const TextStyle(decoration: TextDecoration.none),
      );
      final button = variant == BrandChipButtonVariant.outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: _largeOutlinedStyle,
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: _largeFilledStyle,
              child: child,
            );
      return SizedBox(width: double.infinity, child: button);
    }

    return _CompactChipButton(
      label: label,
      onPressed: onPressed,
      width: fixedWidth ?? double.infinity,
      variant: variant,
    );
  }
}

class _CompactChipButton extends StatelessWidget {
  const _CompactChipButton({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.variant,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final BrandChipButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final outlined = variant == BrandChipButtonVariant.outlined;
    final enabled = onPressed != null;
    final background = outlined
        ? Colors.transparent
        : (enabled ? kBrandYellow : kBrandYellow.withValues(alpha: 0.55));
    final foreground = enabled
        ? kBrandOnYellow
        : kBrandOnYellow.withValues(alpha: 0.7);

    final chip = Material(
      color: background,
      shape: StadiumBorder(
        side: outlined
            ? const BorderSide(color: kBrandYellow, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: kBrandYellow.withValues(alpha: 0.15),
        highlightColor: kBrandYellow.withValues(alpha: 0.08),
        child: SizedBox(
          height: 32,
          width: width == double.infinity ? null : width,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );

    if (width == double.infinity) {
      return SizedBox(width: double.infinity, height: 32, child: chip);
    }
    return SizedBox(width: width, height: 32, child: chip);
  }
}

/// Non-interactive status chip for booking list rows.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({
    super.key,
    required this.status,
    this.width = kBookingsChipWidth,
  });

  final String status;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      "pending" => ("Pending", kBrandYellow, kBrandOnYellow),
      "cancelled" => ("Cancelled", const Color(0xFFE0E0E0), kBrandOnYellow),
      "completed" => (
          "Completed",
          const Color(0xFFC8E6C9),
          const Color(0xFF2E7D32),
        ),
      _ => (status, Colors.grey.shade300, kBrandOnYellow),
    };

    return SizedBox(
      width: width,
      height: 32,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
