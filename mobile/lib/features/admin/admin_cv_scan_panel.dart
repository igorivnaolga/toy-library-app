import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../loans/toy_id_ocr_service.dart";

/// OCR scan of toy ID label at desk check-in. `false` = hidden (code kept).
const bool kDeskToyIdScanEnabled = false;

/// Scan a toy's ID label to jump straight to its check-in.
class AdminCvScanPanel extends StatefulWidget {
  const AdminCvScanPanel({super.key, required this.onToyIdScanned});

  /// Called with a recognised toy id; the parent matches it to an active loan.
  final Future<void> Function(String toyId) onToyIdScanned;

  @override
  State<AdminCvScanPanel> createState() => _AdminCvScanPanelState();
}

class _AdminCvScanPanelState extends State<AdminCvScanPanel> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _scan() async {
    if (_busy) return;
    if (!toyIdOcrSupported) {
      _showMessage("Toy scanning needs an Android or iOS device.");
      return;
    }

    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (shot == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await recognizeToyId(shot.path);
      if (!mounted) return;
      if (!result.hasCandidates) {
        _showMessage("Couldn't read a toy ID. Try again or use the list below.");
        return;
      }
      final toyId = result.candidates.length == 1
          ? result.candidates.first
          : await _chooseCandidate(result.candidates);
      if (toyId == null || !mounted) return;
      await widget.onToyIdScanned(toyId);
    } catch (_) {
      if (mounted) {
        _showMessage("Scan failed. Try again or use the list below.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _chooseCandidate(List<String> candidates) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Which toy ID?", style: context.screenTitle),
        children: [
          for (final id in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, id),
              child: Text("ID $id", style: context.listSubtitle),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
                Text("Scan toy ID", style: context.groupLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Photograph the toy's ID label to find its loan and check it in. "
              "Use manual check-in below if the label can't be read.",
              style: context.listSubtitle,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scan,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: ToyLibraryLoadingIndicator.compact(),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(_busy ? "Reading…" : "Open camera"),
            ),
          ],
        ),
      ),
    );
  }
}
