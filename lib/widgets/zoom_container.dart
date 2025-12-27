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
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> {
  final TransformationController _controller = TransformationController();
  
  double _currentScale = 1.0;
  Offset _currentOffset = Offset.zero;

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

  void resetZoom() {
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