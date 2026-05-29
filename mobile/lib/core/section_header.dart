import "package:flutter/material.dart";

import "app_text_styles.dart";

/// Standard section title above grouped list rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(4, 4, 4, 10),
  });

  final String title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(title, style: context.sectionHeader),
    );
  }
}

/// Muted centered message for empty lists.
class EmptyStateMessage extends StatelessWidget {
  const EmptyStateMessage(
    this.message, {
    super.key,
    this.topSpacing = 120,
  });

  final String message;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: topSpacing),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.emptyState,
          ),
        ),
      ],
    );
  }
}
