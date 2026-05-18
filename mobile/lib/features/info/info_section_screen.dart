import "package:flutter/material.dart";

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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(body, style: theme.textTheme.bodyLarge),
        for (final section in sections) ...[
          const SizedBox(height: 28),
          Text(section.heading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(section.text, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}
