import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_theme.dart";

/// Flyer-style stacked title: serif “CHURCH CORNER” over block “TOY LIBRARY”.
class LibraryAppBarTitle extends StatelessWidget {
  const LibraryAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Church Corner Toy Library",
      header: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kBrandYellow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "CHURCH CORNER",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  height: 1.05,
                  color: kBrandOnYellow,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "TOY LIBRARY",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bebasNeue(
                  fontSize: 14,
                  letterSpacing: 7.0,
                  height: 0.62,
                  color: kBrandOnYellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
