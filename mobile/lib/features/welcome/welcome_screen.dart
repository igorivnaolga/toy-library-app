import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/app_theme.dart";
import "../../core/library_logo_title.dart";

/// One-time welcome shown on first app open: brand yellow, black copy, toy icons.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  static const _toyIcons = [
    Icons.toys,
    Icons.extension,
    Icons.pedal_bike,
    Icons.sports_soccer,
    Icons.palette,
    Icons.castle,
    Icons.pets,
    Icons.directions_car_filled,
  ];

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
              _ToyIconCluster(icons: _toyIcons),
              const SizedBox(height: 40),
              Text(
                "WELCOME TO",
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  height: 1.2,
                  color: kBrandOnYellow,
                ),
              ),
              const SizedBox(height: 20),
              const LibraryLogoTitle(
                size: LibraryLogoSize.welcome,
                showBackground: false,
              ),
              const SizedBox(height: 32),
              Text(
                "bring home a tried, tested and child-proven toy today",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: kBrandOnYellow,
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
                    backgroundColor: kBrandOnYellow,
                    foregroundColor: kBrandYellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(52),
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

class _ToyIconCluster extends StatelessWidget {
  const _ToyIconCluster({required this.icons});

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final icon in icons)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kBrandOnYellow.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: kBrandOnYellow.withValues(alpha: 0.22),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 22, color: kBrandOnYellow),
            ),
        ],
      ),
    );
  }
}
