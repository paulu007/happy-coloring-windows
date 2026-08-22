import 'package:flutter/material.dart';
import '../models/palette_color.dart';
import '../config/constants.dart';
import '../utils/color_utils.dart';

class ColorPalette extends StatelessWidget {
  final List<PaletteColor> colors;
  final PaletteColor? selectedColor;
  final Function(PaletteColor) onColorSelected;
  final bool showProgress;

  const ColorPalette({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onColorSelected,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Scrollbar(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: colors.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final color = colors[index];
            final isSelected = selectedColor?.number == color.number;
            return ColorPaletteItem(
              paletteColor: color,
              isSelected: isSelected,
              showProgress: showProgress,
              onTap: () => onColorSelected(color),
            );
          },
        ),
      ),
    );
  }
}

class ColorPaletteItem extends StatelessWidget {
  final PaletteColor paletteColor;
  final bool isSelected;
  final bool showProgress;
  final VoidCallback onTap;

  const ColorPaletteItem({
    super.key,
    required this.paletteColor,
    required this.isSelected,
    required this.showProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = ColorUtils.getContrastColor(paletteColor.color);
    
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: AppConstants.paletteItemSize,
          height: AppConstants.paletteItemSize,
          decoration: BoxDecoration(
            color: paletteColor.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: paletteColor.color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Color number
            Text(
              paletteColor.number.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            
            // Completed checkmark
            if (paletteColor.isCompleted)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            
            // Progress indicator
            if (showProgress && !paletteColor.isCompleted)
              Positioned(
                bottom: -2,
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: paletteColor.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}