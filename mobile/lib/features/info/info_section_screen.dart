import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";

/// Scrollable info page with optional extra sections below the main body.
class InfoSectionScreen extends StatelessWidget {
  const InfoSectionScreen({
    super.key,
    required this.title,
    required this.body,
    this.sections = const [],
  });

  final String title;
  final String body;
  final List<({String heading, String text})> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(title, style: context.detailTitle),
        const SizedBox(height: 16),
        Text(body, style: context.bodyText),
        for (final section in sections) ...[
          const SizedBox(height: 28),
          Text(section.heading, style: context.infoSectionHeading),
          const SizedBox(height: 8),
          Text(section.text, style: context.bodyText),
        ],
      ],
    );
  }
}
