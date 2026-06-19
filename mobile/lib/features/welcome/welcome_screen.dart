import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/app_theme.dart";
import "../../core/library_logo_title.dart";

/// One-time welcome shown on first app open: brand yellow, soft charcoal copy.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const _appMarkAsset = "assets/app_icon.png";
  static const _ink = kBrandOnYellowSoft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandYellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                _appMarkAsset,
                width: 168,
                height: 168,
                fit: BoxFit.contain,
                semanticLabel: "Toy library building blocks",
              ),
              const SizedBox(height: 40),
              Text(
                "WELCOME TO",
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  height: 1.2,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 20),
              const LibraryLogoTitle(
                size: LibraryLogoSize.welcome,
                showBackground: false,
                foregroundColor: _ink,
              ),
              const SizedBox(height: 32),
              Text(
                "bring home a tried, tested and child-proven toy today",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _ink,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
              ),
              const Spacer(flex: 3),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: kBrandYellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: GoogleFonts.bebasNeue(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2.4,
                    ),
                  ),
                  child: const Text("GET STARTED"),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
