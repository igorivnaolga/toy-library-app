import "package:flutter/material.dart";

import "app_theme.dart";

/// Shared opacity for secondary list/meta text.
const double kTextMutedAlpha = 0.62;

/// Shared opacity for tertiary labels.
const double kTextSubtleAlpha = 0.55;

/// Semantic text styles used across screens, lists, and modals.
extension AppTextStyles on BuildContext {
  TextTheme get _text => Theme.of(this).textTheme;
  ColorScheme get _colors => Theme.of(this).colorScheme;

  /// List section titles: "Upcoming", "On loan", "Past slots".
  TextStyle get sectionHeader => _text.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: _colors.onSurface,
      );

  /// Schedule sheet tabs and in-tab section titles (Duty roster / Library events).
  TextStyle get scheduleMainTabSelected => _text.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: _colors.onSurface,
      );

  TextStyle get scheduleMainTabUnselected => scheduleMainTabSelected.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: _colors.onSurface.withValues(alpha: 0.48),
      );

  TextStyle get scheduleSubTabSelected => _text.titleSmall!.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: _colors.onSurface,
      );

  TextStyle get scheduleSubTabUnselected => scheduleSubTabSelected.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: _colors.onSurface.withValues(alpha: 0.48),
      );

  /// In-tab heading under schedule tabs (matches tab emphasis).
  TextStyle get scheduleSectionTitle => scheduleMainTabSelected.copyWith(
        fontSize: 17,
      );

  /// Sheet / modal screen titles on white background.
  TextStyle get screenTitle => _text.titleLarge!.copyWith(
        fontWeight: FontWeight.w700,
        color: _colors.onSurface,
      );

  /// Primary title on list cards and tiles.
  TextStyle get cardTitle => _text.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: _colors.onSurface,
        height: 1.2,
      );

  /// De-emphasised card title (past items, cancelled rows).
  TextStyle get cardTitleMuted => cardTitle.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextMutedAlpha),
      );

  /// Hero title on detail screens.
  TextStyle get detailTitle => _text.headlineSmall!.copyWith(
        fontWeight: FontWeight.w700,
        color: _colors.onSurface,
        height: 1.2,
      );

  /// Secondary line under a card title.
  TextStyle get listSubtitle => _text.bodySmall!.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextMutedAlpha),
        height: 1.25,
        fontWeight: FontWeight.w500,
      );

  /// Muted body line (profile email, membership hints).
  TextStyle get profileSecondary => _text.bodyMedium!.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextMutedAlpha),
      );

  /// Secondary body line on list tiles (time range, etc.).
  TextStyle listSecondary({bool muted = false}) => _text.bodyMedium!.copyWith(
        color: muted
            ? _colors.onSurface.withValues(alpha: kTextMutedAlpha)
            : _colors.onSurface,
      );

  /// Emphasised secondary line (e.g. assignee name).
  TextStyle get listSecondaryEmphasis => listSecondary().copyWith(
        fontWeight: FontWeight.w600,
      );

  /// Label in key/value meta rows.
  TextStyle get metaLabel => _text.bodySmall!.copyWith(
        fontWeight: FontWeight.w600,
        color: _colors.onSurface.withValues(alpha: kTextSubtleAlpha),
      );

  /// Value in key/value meta rows.
  TextStyle get metaValue => _text.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: _colors.onSurface,
      );

  /// Empty states and inline helper messages.
  TextStyle get emptyState => _text.bodyMedium!.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextMutedAlpha),
      );

  /// Small label above a grouped list item.
  TextStyle get groupLabel => _text.labelLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: _colors.onSurface.withValues(alpha: 0.85),
      );

  /// Titles on yellow modal headers.
  TextStyle get modalTitleOnYellow => _text.titleLarge!.copyWith(
        fontWeight: FontWeight.w700,
        color: kBrandOnYellow,
      );

  /// Option titles inside yellow modal lists.
  TextStyle get modalOptionTitle => _text.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: kBrandOnYellow,
      );

  /// Body text on detail / info screens.
  TextStyle get bodyText => _text.bodyMedium!.copyWith(
        fontWeight: FontWeight.w400,
        color: _colors.onSurface.withValues(alpha: 0.82),
        height: 1.45,
      );

  /// Placeholder body when content is missing.
  TextStyle get bodyPlaceholder => bodyText.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextSubtleAlpha),
      );

  /// Profile / form section labels.
  TextStyle get formSectionLabel => _text.labelSmall!.copyWith(
        color: _colors.onSurface.withValues(alpha: kTextSubtleAlpha),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );

  /// Info page section headings.
  TextStyle get infoSectionHeading => sectionHeader;

  /// Panel headings inside cards (e.g. walk-in checkout).
  TextStyle get panelTitle => cardTitle;

  /// Small panel subtitles and captions on yellow backgrounds.
  TextStyle get captionOnYellow => _text.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: kBrandOnYellow.withValues(alpha: 0.75),
      );

  /// Helper / body copy on yellow or brand-tinted surfaces.
  TextStyle get bodyOnYellow => _text.bodyMedium!.copyWith(
        color: kBrandOnYellow.withValues(alpha: 0.72),
        height: 1.35,
      );

  /// Compact filter / chip labels in the catalog toolbar.
  TextStyle filterChipLabel({bool active = false}) => TextStyle(
        fontSize: 12,
        fontWeight: active ? FontWeight.w800 : FontWeight.w700,
        color: kBrandOnYellow,
        height: 1.1,
      );

  /// Small action label on yellow buttons (e.g. "Clear filters").
  TextStyle get filterActionLabel => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kBrandOnYellow,
      );
}
