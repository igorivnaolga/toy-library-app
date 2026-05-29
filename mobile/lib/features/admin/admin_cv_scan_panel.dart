import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";

/// Placeholder for future computer-vision toy identification at check-in.
class AdminCvScanPanel extends StatelessWidget {
  const AdminCvScanPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  "Scan toy (coming soon)",
                  style: context.groupLabel,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Computer vision check-in will identify returned toys from a photo. "
              "Use manual check-in below until then.",
              style: context.listSubtitle,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Open camera"),
            ),
          ],
        ),
      ),
    );
  }
}
