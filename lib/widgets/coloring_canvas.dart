import 'package:flutter/material.dart';
import '../models/color_region.dart';
import '../models/palette_color.dart';
import '../config/constants.dart';
import '../utils/color_utils.dart';

class ColoringCanvas extends StatelessWidget {
  final List<ColorRegion> regions;
  final PaletteColor? selectedColor;
  final bool showNumbers;
  final bool highlightSelected;
  final bool hintMode;
  final Function(Offset) onTap;

  const ColoringCanvas({
    super.key,
    required this.regions,
    required this.selectedColor,
    required this.showNumbers,
    required this.highlightSelected,
    required this.hintMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => onTap(details.localPosition),
      child: CustomPaint(
        painter: ColoringPainter(
          regions: regions,
          selectedColor: selectedColor,
          showNumbers: showNumbers,
          highlightSelected: highlightSelected,
          hintMode: hintMode,
        ),
        size: Size.infinite,
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

  ColoringPainter({
    required this.regions,
    required this.selectedColor,
    required this.showNumbers,
    required this.highlightSelected,
    required this.hintMode,
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
      } else if (highlightSelected && selectedColor != null &&
                 region.colorNumber == selectedColor!.number) {
        // Highlight mode - pulse effect
        fillPaint.color = AppColors.unfilled;
      } else {
        fillPaint.color = AppColors.unfilled;
      }

      // Draw filled region
      canvas.drawPath(region.path, fillPaint);
      
      // Draw stroke
      canvas.drawPath(region.path, strokePaint);

      // Draw number if not filled and showNumbers is enabled
      if (!region.isFilled && showNumbers) {
        _drawNumber(canvas, region);
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

  void _drawNumber(Canvas canvas, ColorRegion region) {
    final textSpan = TextSpan(
      text: region.colorNumber.toString(),
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppConstants.numberFontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();

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
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ColoringPainter oldDelegate) {
    return oldDelegate.regions != regions ||
           oldDelegate.selectedColor != selectedColor ||
           oldDelegate.showNumbers != showNumbers ||
           oldDelegate.highlightSelected != highlightSelected ||
           oldDelegate.hintMode != hintMode;
  }
}