import "package:flutter/material.dart";

class ToyLibraryApp extends StatelessWidget {
  const ToyLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("Toy Library App"),
        ),
      ),
    );
  }
}
