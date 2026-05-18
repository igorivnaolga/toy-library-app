import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/auth_store.dart";
import "auth_messages.dart";

/// Login / registration UI for members/admins.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _validate() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains("@")) {
      return "Enter a valid email.";
    }
    if (password.length < 6) {
      return "Password must be at least 6 characters.";
    }
    return null;
  }

  Future<void> _handleSignIn() async {
    final validationError = _validate();
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    final auth = context.read<AuthStore>();
    await auth.signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (auth.error == null && auth.isLoggedIn) {
      await showAuthSuccessDialog(
        context,
        title: "Signed in",
        message: signedInMessage(
          needsMembershipOnboarding: auth.needsMembershipOnboarding,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSignUp() async {
    final validationError = _validate();
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    final auth = context.read<AuthStore>();
    await auth.signUp(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (auth.error == null) {
      if (auth.isLoggedIn) {
        await showAuthSuccessDialog(
          context,
          title: "Account created",
          message: accountCreatedMessage,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        await showAuthSuccessDialog(
          context,
          title: "Confirm your email",
          message: emailConfirmationMessage,
        );
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return Scaffold(
      appBar: AppBar(title: const Text("Sign in")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: "Email"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: auth.loading ? null : _handleSignIn,
            child: const Text("Sign in"),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: auth.loading ? null : _handleSignUp,
            child: const Text("Create account"),
          ),
          if (auth.loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (auth.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                auth.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
