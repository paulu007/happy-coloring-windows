import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../config/constants.dart';

class ZoomContainer extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Function(double scale, Offset offset)? onTransformChanged;

  const ZoomContainer({
    super.key,
    required this.child,
    this.minScale = AppConstants.minZoom,
    this.maxScale = AppConstants.maxZoom,
    this.onTransformChanged,
  });

  @override
  State<ZoomContainer> createState() => ZoomContainerState();
}

class ZoomContainerState extends State<ZoomContainer> {
  final TransformationController _controller = TransformationController();

  double _currentScale = 1.0;
  Offset _currentOffset = Offset.zero;

  double get scale => _currentScale;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final matrix = _controller.value;
    _currentScale = matrix.getMaxScaleOnAxis();
    _currentOffset = Offset(matrix.getTranslation().x, matrix.getTranslation().y);

    widget.onTransformChanged?.call(_currentScale, _currentOffset);
  }

  /// Multiply the current zoom by [factor], keeping the viewport center
  /// anchored. Exposed so toolbar buttons and keyboard shortcuts can drive
  /// the same transform the gestures use.
  void zoomBy(double factor) {
    final size = context.size;
    if (size == null) return;

    final old = _controller.value;
    final oldScale = old.getMaxScaleOnAxis();
    final target =
        (oldScale * factor).clamp(widget.minScale, widget.maxScale);
    final actual = target / oldScale;
    if ((actual - 1.0).abs() < 0.0001) return;

    final center = size.center(Offset.zero);
    final updated = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(actual, actual, 1.0)
      ..translate(-center.dx, -center.dy)
      ..multiply(old);

    _controller.value = updated;
    _currentScale = target;
    widget.onTransformChanged?.call(_currentScale, _currentOffset);
  }

  void zoomIn() => zoomBy(1.2);

  void zoomOut() => zoomBy(1 / 1.2);

  void resetView() {
    _controller.value = Matrix4.identity();
    _currentScale = 1.0;
    _currentOffset = Offset.zero;
    widget.onTransformChanged?.call(_currentScale, _currentOffset);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      onInteractionUpdate: _onInteractionUpdate,
      boundaryMargin: const EdgeInsets.all(100),
      child: widget.child,
    );
  }
}
