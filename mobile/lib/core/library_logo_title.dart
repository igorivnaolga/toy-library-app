import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_theme.dart";

/// Flyer-style stacked logo type: serif “CHURCH CORNER” over block “TOY LIBRARY”.
class LibraryLogoTitle extends StatelessWidget {
  const LibraryLogoTitle({
    super.key,
    this.size = LibraryLogoSize.appBar,
    this.showBackground = true,
  });

  final LibraryLogoSize size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final churchCornerStyle = GoogleFonts.playfairDisplay(
      fontSize: size.churchCornerFontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      height: 1.05,
      color: kBrandOnYellow,
    );
    final toyLibraryStyle = GoogleFonts.bebasNeue(
      fontSize: size.toyLibraryFontSize,
      letterSpacing: 7.0,
      height: 0.62,
      color: kBrandOnYellow,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "CHURCH CORNER",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: churchCornerStyle,
        ),
        SizedBox(height: size.lineGap),
        Text(
          "TOY LIBRARY",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: toyLibraryStyle,
        ),
      ],
    );

    if (!showBackground) {
      return content;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kBrandYellow,
        borderRadius: BorderRadius.circular(size.backgroundRadius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size.horizontalPadding,
          vertical: size.verticalPadding,
        ),
        child: content,
      ),
    );
  }
}

enum LibraryLogoSize {
  appBar(
    churchCornerFontSize: 11,
    toyLibraryFontSize: 14,
    lineGap: 5,
    horizontalPadding: 10,
    verticalPadding: 5,
    backgroundRadius: 8,
  ),
  welcome(
    churchCornerFontSize: 26,
    toyLibraryFontSize: 56,
    lineGap: 10,
    horizontalPadding: 20,
    verticalPadding: 14,
    backgroundRadius: 12,
  );

  const LibraryLogoSize({
    required this.churchCornerFontSize,
    required this.toyLibraryFontSize,
    required this.lineGap,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.backgroundRadius,
  });

  final double churchCornerFontSize;
  final double toyLibraryFontSize;
  final double lineGap;
  final double horizontalPadding;
  final double verticalPadding;
  final double backgroundRadius;
}

/// Compact logo badge for the app bar (top-left).
class LibraryAppBarTitle extends StatelessWidget {
  const LibraryAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Church Corner Toy Library",
      header: true,
      child: const LibraryLogoTitle(),
    );
  }
}
