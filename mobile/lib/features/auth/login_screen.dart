import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_input_field.dart";
import "../../core/auth_store.dart";
import "auth_messages.dart";
import "forgot_password_screen.dart";
import "registration_screen.dart";
import "registration_validation.dart";

/// Login / registration UI for members/admins.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  AuthStore? _auth;
  String? _emailError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_onEmailFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthStore>().clearError();
    });
  }

  void _onEmailFocusChange() {
    if (!_emailFocus.hasFocus) {
      _validateEmail();
    }
  }

  void _validateEmail() {
    final error = RegistrationValidation.requiredEmail(_email.text);
    if (error != _emailError) {
      setState(() => _emailError = error);
    }
  }

  void _clearEmailError() {
    if (_emailError == null) return;
    setState(() => _emailError = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= context.read<AuthStore>();
  }

  String? _validate() {
    _validateEmail();
    if (_emailError != null) return _emailError;
    if (_password.text.isEmpty) {
      return "Enter your password.";
    }
    return null;
  }

  void _clearAuthError(AuthStore auth) {
    auth.clearError();
  }

  Future<void> _handleSignIn() async {
    final validationError = _validate();
    if (validationError != null) {
      if (!mounted) return;
      if (validationError != _emailError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(validationError)));
      }
      return;
    }
    final auth = context.read<AuthStore>();
    await auth.signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (auth.error == null && auth.isLoggedIn) {
      await showAuthSuccessDialog(
        context,
        title: "Signed in",
        content: SignedInWelcomeContent(
          needsMembershipOnboarding: auth.needsMembershipOnboarding,
          fullName: auth.fullName,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
      ),
    );
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegistrationScreen()),
    );
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChange);
    _emailFocus.dispose();
    _auth?.clearError();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Sign in or register")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!auth.isAuthConfigured)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Supabase auth is not loaded. Stop the app and run with "
                  "mobile/env/dev.json, e.g.\n"
                  "flutter run --dart-define-from-file=env/dev.json "
                  "--dart-define=USE_ADB_REVERSE=true",
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          if (!auth.isAuthConfigured) const SizedBox(height: 12),
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
              _clearEmailError();
              _clearAuthError(auth);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: labeledInputDecoration(
              context,
              labelText: "Password",
              suffixIcon: passwordVisibilitySuffix(
                context,
                visible: !_obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => _clearAuthError(auth),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.loading ? null : _openForgotPassword,
              child: const Text("Forgot password?"),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: auth.loading ? null : _handleSignIn,
            child: const Text("Sign in"),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: auth.loading ? null : _openRegistration,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.toys),
            label: const Text("Join the library"),
          ),
          if (auth.loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: ToyLibraryLoadingIndicator()),
            ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  auth.error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
