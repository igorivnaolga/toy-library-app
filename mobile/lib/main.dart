/// Flutter entrypoint.
///
/// Keep this file tiny: app wiring belongs in `app.dart`, feature code lives under
/// `features/`, and cross-cutting concerns (HTTP, auth tokens) live under `core/`.
import "package:flutter/material.dart";

import "app.dart";

void main() {
  // `runApp` attaches the widget tree to the screen and starts the framework.
  runApp(const ToyLibraryApp());
}
