import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart';

class PathUtils {
  /// Parse SVG path data string to Flutter Path
  static Path parseSvgPath(String pathData) {
    return parseSvgPathData(pathData);
  }

  /// Get the center point of a path
  static Offset getCenterPoint(Path path) {
    final bounds = path.getBounds();
    return Offset(
      bounds.left + bounds.width / 2,
      bounds.top + bounds.height / 2,
    );
  }

  /// Get bounds of multiple paths combined
  static Rect getCombinedBounds(List<Path> paths) {
    if (paths.isEmpty) return Rect.zero;

    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final path in paths) {
      final bounds = path.getBounds();
      if (bounds.left < left) left = bounds.left;
      if (bounds.top < top) top = bounds.top;
      if (bounds.right > right) right = bounds.right;
      if (bounds.bottom > bottom) bottom = bounds.bottom;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Scale a path by a factor
  static Path scalePath(Path path, double scale) {
    final matrix = Matrix4.identity()..scale(scale, scale);
    return path.transform(matrix.storage);
  }

  /// Translate a path by offset
  static Path translatePath(Path path, Offset offset) {
    final matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    return path.transform(matrix.storage);
  }
}