import 'package:flutter/material.dart';
import '../models/color_region.dart';
import '../models/palette_color.dart';
import '../config/constants.dart';

/// Cache of laid-out number text painters, keyed by color number.
/// Laying out text is expensive; regions reuse the same handful of numbers
/// every frame, so each number is laid out only once.
final Map<int, TextPainter> _numberPainterCache = {};

TextPainter _numberPainterFor(int number) {
  return _numberPainterCache.putIfAbsent(number, () {
    final painter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppConstants.numberFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    return painter;
  });
}

class ColoringCanvas extends StatelessWidget {
  final List<ColorRegion> regions;
  final PaletteColor? selectedColor;
  final bool showNumbers;
  final bool highlightSelected;
  final bool hintMode;

  /// Region whose number is momentarily revealed (tap/long-press), even when
  /// [showNumbers] is false.
  final int? revealedRegionId;

  /// Monotonic counter bumped on every fill/undo/redo so the painter knows
  /// the region states changed (regions are mutated in place).
  final int revision;

  final Function(Offset) onTap;
  final Function(Offset)? onLongPress;

  const ColoringCanvas({
    super.key,
    required this.regions,
    required this.selectedColor,
    required this.showNumbers,
    required this.highlightSelected,
    required this.hintMode,
    this.revealedRegionId,
    this.revision = 0,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        // onTapUp (not onTapDown) so a long-press reveal or a pan/zoom drag
        // never also triggers a fill.
        onTapUp: (details) => onTap(details.localPosition),
        onLongPressStart: onLongPress != null
            ? (details) => onLongPress!(details.localPosition)
            : null,
        child: CustomPaint(
          painter: ColoringPainter(
            regions: regions,
            selectedColor: selectedColor,
            showNumbers: showNumbers,
            highlightSelected: highlightSelected,
            hintMode: hintMode,
            revealedRegionId: revealedRegionId,
            revision: revision,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class ColoringPainter extends CustomPainter {
  final List<ColorRegion> regions;
  final PaletteColor? selectedColor;
  final bool showNumbers;
  final bool highlightSelected;
  final bool hintMode;
  final int? revealedRegionId;
  final int revision;

  ColoringPainter({
    required this.regions,
    required this.selectedColor,
    required this.showNumbers,
    required this.highlightSelected,
    required this.hintMode,
    this.revealedRegionId,
    required this.revision,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.strokeWidth
      ..color = AppColors.stroke;

    // Draw all regions
    for (final region in regions) {
      // Determine fill color
      if (region.isFilled) {
        fillPaint.color = region.targetColor;
      } else if (hintMode && selectedColor != null &&
          region.colorNumber == selectedColor!.number) {
        // Hint mode - show target color with transparency
        fillPaint.color = region.targetColor.withOpacity(0.3);
      } else {
        fillPaint.color = AppColors.unfilled;
      }

      // Draw filled region
      canvas.drawPath(region.path, fillPaint);

      // Draw stroke
      canvas.drawPath(region.path, strokePaint);

      // Numbers are hidden by default for a clean canvas. They are still
      // tracked per region (region.colorNumber) and drive fill validation;
      // a single number can be revealed on demand.
      final isRevealed = revealedRegionId == region.id;
      if (!region.isFilled && (showNumbers || isRevealed)) {
        _drawNumber(canvas, region, highlighted: isRevealed && !showNumbers);
      }
    }

    // Draw highlight border for selected color regions
    if (highlightSelected && selectedColor != null) {
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = selectedColor!.color;

      for (final region in regions) {
        if (!region.isFilled && region.colorNumber == selectedColor!.number) {
          canvas.drawPath(region.path, highlightPaint);
        }
      }
    }
  }

  void _drawNumber(Canvas canvas, ColorRegion region,
      {bool highlighted = false}) {
    final textPainter = _numberPainterFor(region.colorNumber);

    final offset = Offset(
      region.centerPoint.dx - textPainter.width / 2,
      region.centerPoint.dy - textPainter.height / 2,
    );

    // Draw background for better visibility
    final bgRect = Rect.fromCenter(
      center: region.centerPoint,
      width: textPainter.width + 4,
      height: textPainter.height + 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(2)),
      Paint()
        ..color = highlighted
            ? AppColors.primary.withOpacity(0.92)
            : Colors.white.withOpacity(0.8),
    );

    if (highlighted) {
      // Reveal flash uses a white-on-primary badge instead of the cached
      // dark text painter, so it stands out against the white regions.
      final white = TextPainter(
        text: TextSpan(
          text: region.colorNumber.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: AppConstants.numberFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      white.paint(
        canvas,
        Offset(
          region.centerPoint.dx - white.width / 2,
          region.centerPoint.dy - white.height / 2,
        ),
      );
    } else {
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant ColoringPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.regions != regions ||
        oldDelegate.selectedColor != selectedColor ||
        oldDelegate.showNumbers != showNumbers ||
        oldDelegate.highlightSelected != highlightSelected ||
        oldDelegate.hintMode != hintMode ||
        oldDelegate.revealedRegionId != revealedRegionId;
  }
}
