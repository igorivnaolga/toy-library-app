import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";

/// Branded container for toy detail sections.
class ToyDetailSectionCard extends StatelessWidget {
  const ToyDetailSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Label/value row for toy metadata on the detail screen.
class ToyDetailMetaRow extends StatelessWidget {
  const ToyDetailMetaRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: context.metaLabel.copyWith(height: 1.35),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.metaValue.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading used inside detail cards (e.g. Description).
class ToyDetailSectionTitle extends StatelessWidget {
  const ToyDetailSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.sectionHeader.copyWith(height: 1.2));
  }
}
