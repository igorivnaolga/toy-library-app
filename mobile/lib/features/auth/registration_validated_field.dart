import "package:flutter/material.dart";

import "../../core/app_input_field.dart";

/// Runs [validator] when the user leaves the field; shows a snackbar and
/// inline error text when the value is invalid.
class RegistrationValidatedField extends StatefulWidget {
  const RegistrationValidatedField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.optional = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String value) validator;
  final bool optional;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  State<RegistrationValidatedField> createState() =>
      RegistrationValidatedFieldState();
}

class RegistrationValidatedFieldState extends State<RegistrationValidatedField> {
  final FocusNode _focusNode = FocusNode();
  String? _error;

  String? get error => _error;

  /// Validates the field and updates inline error state. Returns true if valid.
  bool validate({bool showSnackBar = false}) {
    _validate(showSnackBar: showSnackBar);
    return _error == null;
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _validate(showSnackBar: true);
    }
  }

  void _onTextChanged() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  void _validate({required bool showSnackBar}) {
    final value = widget.controller.text;
    String? error;
    if (widget.optional && value.trim().isEmpty) {
      error = null;
    } else {
      error = widget.validator(value);
    }

    if (error != _error) {
      setState(() => _error = error);
    }

    if (showSnackBar && error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      style: fieldTextStyle(context),
      cursorColor: fieldCursorColor(context),
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      textCapitalization: widget.textCapitalization,
      textInputAction:
          widget.maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      onEditingComplete: () {
        _validate(showSnackBar: true);
        FocusScope.of(context).nextFocus();
      },
      decoration: labeledInputDecoration(
        context,
        labelText: widget.label,
        errorText: _error,
      ),
    );
  }
}
