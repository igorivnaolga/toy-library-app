import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "auth_error_messages.dart";
import "auth_messages.dart";
import "registration_validation.dart";

/// Sends a Supabase password-reset email (no account enumeration on success).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  final _emailFocus = FocusNode();
  bool _busy = false;
  String? _emailError;
  String? _submitError;
  bool _emailTouched = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? "");
    _emailFocus.addListener(_onEmailFocusChange);
  }

  void _onEmailFocusChange() {
    if (!_emailFocus.hasFocus) {
      _validateEmail(force: true);
    }
  }

  void _validateEmail({bool force = false}) {
    if (!force && !_emailTouched) return;
    final error = RegistrationValidation.requiredEmail(_email.text);
    if (error != _emailError) {
      setState(() => _emailError = error);
    }
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChange);
    _emailFocus.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _validateEmail(force: true);
    if (_emailError != null) return;

    final auth = context.read<AuthStore>();
    setState(() {
      _busy = true;
      _submitError = null;
    });

    final email = _email.text.trim();
    final sent = await auth.requestPasswordReset(email: email);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!sent) {
      setState(() {
        _submitError = auth.error ?? "Couldn't send the reset email.";
      });
      return;
    }

    await showAuthSuccessDialog(
      context,
      title: "Check your email",
      message: passwordResetRequestMessage(email: email),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset password")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Enter the email you used to join the library. "
            "We'll send a link to reset your password.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: labeledInputDecoration(
              context,
              labelText: "Email",
              errorText: _emailError,
            ),
            onChanged: (_) {
              _emailTouched = true;
              _validateEmail();
              if (_submitError != null) {
                setState(() => _submitError = null);
              }
            },
          ),
          const SizedBox(height: 20),
          BrandChipButton(
            label: _busy ? "Sending…" : "Send reset link",
            large: true,
            onPressed: _busy ? null : _submit,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
