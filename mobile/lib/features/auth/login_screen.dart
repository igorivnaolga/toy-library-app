import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/auth_store.dart";

/// Login / registration UI for members/admins.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

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
            onPressed: auth.loading
                ? null
                : () => context.read<AuthStore>().signIn(
                      email: _email.text,
                      password: _password.text,
                    ),
            child: const Text("Sign in"),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: auth.loading
                ? null
                : () => context.read<AuthStore>().signUp(
                      email: _email.text,
                      password: _password.text,
                    ),
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
          const SizedBox(height: 20),
          Text(
            "Guest browsing is still available from the app home.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
