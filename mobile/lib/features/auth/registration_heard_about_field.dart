import "package:flutter/material.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "registration_validation.dart";

/// Stored values sent to the API (stats-friendly labels).
const heardAboutSourceFriend = "friend";
const heardAboutSourceFacebook = "facebook";
const heardAboutSourceInstagram = "instagram";
const heardAboutSourceGoogle = "google";
const heardAboutSourceOther = "other";

const heardAboutSourceOptions = <(String id, String label)>[
  (heardAboutSourceFriend, "Friend"),
  (heardAboutSourceFacebook, "Facebook"),
  (heardAboutSourceInstagram, "Instagram"),
  (heardAboutSourceGoogle, "Google"),
  (heardAboutSourceOther, "Other"),
];

String resolveHeardAboutUs({
  required String? source,
  required String otherText,
}) {
  switch (source) {
    case heardAboutSourceFriend:
      return "Friend";
    case heardAboutSourceFacebook:
      return "Facebook";
    case heardAboutSourceInstagram:
      return "Instagram";
    case heardAboutSourceGoogle:
      return "Google";
    case heardAboutSourceOther:
      return otherText.trim();
    default:
      return "";
  }
}

/// Radio options for how the member heard about the library.
class RegistrationHeardAboutField extends StatefulWidget {
  const RegistrationHeardAboutField({
    super.key,
    required this.selectedSource,
    required this.otherController,
    required this.onSourceChanged,
  });

  final String? selectedSource;
  final TextEditingController otherController;
  final ValueChanged<String?> onSourceChanged;

  @override
  State<RegistrationHeardAboutField> createState() =>
      RegistrationHeardAboutFieldState();
}

class RegistrationHeardAboutFieldState extends State<RegistrationHeardAboutField> {
  String? _error;

  String? get error => _error;

  bool validate({bool showSnackBar = false}) {
    final message = RegistrationValidation.heardAboutUs(
      widget.selectedSource,
      widget.otherController.text,
    );
    if (message != _error) {
      setState(() => _error = message);
    }
    if (message != null && showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    return message == null;
  }

  @override
  void initState() {
    super.initState();
    widget.otherController.addListener(_clearErrorOnChange);
  }

  @override
  void dispose() {
    widget.otherController.removeListener(_clearErrorOnChange);
    super.dispose();
  }

  void _clearErrorOnChange() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _selectSource(String? source) {
    widget.onSourceChanged(source);
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "How did you hear about us?",
          style: context.sectionHeader.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          "Choose one option",
          style: context.listSubtitle.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final option in heardAboutSourceOptions)
          RadioListTile<String>(
            value: option.$1,
            groupValue: widget.selectedSource,
            onChanged: _selectSource,
            title: Text(
              option.$2,
              style: context.bodyText.copyWith(fontWeight: FontWeight.w500),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        if (widget.selectedSource == heardAboutSourceOther) ...[
          const SizedBox(height: 4),
          TextField(
            controller: widget.otherController,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            textCapitalization: TextCapitalization.sentences,
            decoration: labeledInputDecoration(
              context,
              labelText: "Please tell us",
              hintText: "e.g. school newsletter, flyer",
              errorText: _error != null &&
                      widget.selectedSource == heardAboutSourceOther
                  ? _error
                  : null,
            ),
          ),
        ],
        if (_error != null && widget.selectedSource != heardAboutSourceOther)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
