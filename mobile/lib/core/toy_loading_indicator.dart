import "dart:math" as math;

import "package:flutter/material.dart";

import "app_text_styles.dart";
import "app_theme.dart";

/// Playful toy-library loader: three ABC blocks orbiting in brand colours.
class ToyLibraryLoadingIndicator extends StatefulWidget {
  const ToyLibraryLoadingIndicator({
    super.key,
    this.size = 52,
    this.message,
  });

  /// Small inline loader (search fields, buttons, list footers).
  const ToyLibraryLoadingIndicator.compact({super.key, this.message})
      : size = 22;

  final double size;
  final String? message;

  @override
  State<ToyLibraryLoadingIndicator> createState() =>
      _ToyLibraryLoadingIndicatorState();
}

class _ToyLibraryLoadingIndicatorState extends State<ToyLibraryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinner = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _ToyBlocksSpinnerPainter(
            progress: _controller.value,
            compact: widget.size <= 24,
          ),
        );
      },
    );

    if (widget.message == null || widget.message!.isEmpty) {
      return spinner;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinner,
        const SizedBox(height: 16),
        Text(
          widget.message!,
          textAlign: TextAlign.center,
          style: context.emptyState,
        ),
      ],
    );
  }
}

class _ToyBlocksSpinnerPainter extends CustomPainter {
  _ToyBlocksSpinnerPainter({
    required this.progress,
    required this.compact,
  });

  final double progress;
  final bool compact;

  static const _blocks = [
    _BlockSpec(color: kBrandYellow, letter: "A", textColor: kBrandOnYellow),
    _BlockSpec(color: Color(0xFF6FB3E0), letter: "B", textColor: Colors.white),
    _BlockSpec(color: Color(0xFF7BC67E), letter: "C", textColor: Colors.white),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbit = size.width * (compact ? 0.28 : 0.32);
    final blockSide = size.width * (compact ? 0.34 : 0.36);
    final corner = blockSide * 0.18;
    final angleOffset = progress * 2 * math.pi;

    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      final angle = angleOffset + i * 2 * math.pi / _blocks.length;
      final blockCenter = Offset(
        center.dx + orbit * math.cos(angle),
        center.dy + orbit * math.sin(angle),
      );

      final rect = Rect.fromCenter(
        center: blockCenter,
        width: blockSide,
        height: blockSide,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(corner));

      canvas.drawShadow(
        Path()..addRRect(rrect),
        kBrandOnYellow.withValues(alpha: 0.18),
        compact ? 1.5 : 3,
        false,
      );

      final fill = Paint()..color = block.color;
      canvas.drawRRect(rrect, fill);

      final border = Paint()
        ..color = kBrandOnYellow.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 0.8 : 1.2;
      canvas.drawRRect(rrect, border);

      final fontSize = blockSide * (compact ? 0.52 : 0.48);
      final textPainter = TextPainter(
        text: TextSpan(
          text: block.letter,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: block.textColor,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        blockCenter -
            Offset(textPainter.width / 2, textPainter.height / 2 - 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ToyBlocksSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.compact != compact;
  }
}

class _BlockSpec {
  const _BlockSpec({
    required this.color,
    required this.letter,
    required this.textColor,
  });

  final Color color;
  final String letter;
  final Color textColor;
}
