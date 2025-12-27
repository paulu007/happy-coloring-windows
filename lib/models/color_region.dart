import 'dart:ui';

class ColorRegion {
  final int id;
  final Path path;
  final int colorNumber;
  final Color targetColor;
  final Offset centerPoint;
  bool isFilled;

  ColorRegion({
    required this.id,
    required this.path,
    required this.colorNumber,
    required this.targetColor,
    required this.centerPoint,
    this.isFilled = false,
  });

  // Check if a point is inside this region
  bool containsPoint(Offset point) {
    return path.contains(point);
  }

  // Create a copy with updated filled status
  ColorRegion copyWith({bool? isFilled}) {
    return ColorRegion(
      id: id,
      path: path,
      colorNumber: colorNumber,
      targetColor: targetColor,
      centerPoint: centerPoint,
      isFilled: isFilled ?? this.isFilled,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'colorNumber': colorNumber,
      'isFilled': isFilled ? 1 : 0,
    };
  }
}