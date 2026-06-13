import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "auth_messages.dart";
import "registration_form_data.dart";

/// Final registration step: create the Supabase account and save the form.
class RegistrationPasswordScreen extends StatefulWidget {
  const RegistrationPasswordScreen({super.key, required this.form});

  final RegistrationFormData form;

  @override
  State<RegistrationPasswordScreen> createState() =>
      _RegistrationPasswordScreenState();
}

class _RegistrationPasswordScreenState extends State<RegistrationPasswordScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validatePassword() {
    if (_password.text.length < 6) {
      return "Password must be at least 6 characters.";
    }
    if (_password.text != _confirmPassword.text) {
      return "Passwords do not match.";
    }
    return null;
  }

  Future<void> _createAccount() async {
    final validationError = _validatePassword();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final auth = context.read<AuthStore>();
    if (!auth.isAuthConfigured) {
      setState(() {
        _error = "Auth is not configured. Rebuild the app with mobile/env/dev.json "
            "(SUPABASE_URL and SUPABASE_ANON_KEY). See env/dev.json.example.";
      });
      return;
    }
    final backend = context.read<BackendClient>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.signUp(
        email: widget.form.email.trim(),
        password: _password.text,
      );
      if (auth.error != null) {
        throw Exception(auth.error);
      }
      if (!auth.isLoggedIn) {
        if (!mounted) return;
        await showAuthSuccessDialog(
          context,
          title: "Confirm your email",
          message: emailConfirmationMessage,
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      await backend.postJson(
        "/api/v1/auth/me/registration",
        widget.form.toRegistrationJson(),
      );
      await auth.refreshProfile(silent: true);

      if (!mounted) return;
      auth.markPostRegistrationWelcome();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create your password")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Almost done. Choose a password for ${widget.form.email.trim()}.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _password,
            obscureText: true,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: labeledInputDecoration(context, labelText: "Password"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration:
                labeledInputDecoration(context, labelText: "Confirm password"),
          ),
          const SizedBox(height: 20),
          BrandChipButton(
            label: _busy ? "Creating account…" : "Create account",
            large: true,
            onPressed: _busy ? null : _createAccount,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
