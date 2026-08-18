import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/color_region.dart';
import '../providers/coloring_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/color_palette.dart';
import '../widgets/zoom_container.dart';

class ColoringScreen extends StatefulWidget {
  final String imageId;

  const ColoringScreen({
    super.key,
    required this.imageId,
  });

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with TickerProviderStateMixin {
  late ColoringProvider _coloringProvider;
  late AnimationController _completionController;
  late Animation<double> _completionAnimation;

  // Momentarily revealed region number (tap with wrong color or long-press).
  int? _revealedRegionId;
  Timer? _revealTimer;

  // Force-show numbers overlay (useful when recording or exporting an image)
  bool _forceShowNumbers = false;

  // Key used to capture the canvas image for export
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    _coloringProvider = ColoringProvider();
    _coloringProvider.loadImage(widget.imageId);

    _completionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _completionAnimation = CurvedAnimation(
      parent: _completionController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _coloringProvider.dispose();
    _completionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _coloringProvider,
      child: Consumer<ColoringProvider>(
        builder: (context, provider, child) {
          // Show completion dialog when completed
          if (provider.state == ColoringState.completed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCompletionDialog();
            });
          }

          return Scaffold(
            appBar: _buildAppBar(provider),
            body: _buildBody(provider),
            bottomNavigationBar: _buildBottomBar(provider),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColoringProvider provider) {
    return AppBar(
      title: Text(provider.currentImage?.name ?? 'Loading...'),
      actions: [
        // Toggle numbers overlay for recording/export (forced)
        IconButton(
          icon: Icon(
            _forceShowNumbers ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => setState(() => _forceShowNumbers = !_forceShowNumbers),
          tooltip: _forceShowNumbers ? 'Hide Numbers (forced)' : 'Show Numbers (forced)',
        ),

        // Export canvas (PNG) - captures current view. If forced numbers are on
        // they'll appear in the exported image.
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _exportCanvasWithNumbers,
          tooltip: 'Export PNG',
        ),

        // Hint button
        IconButton(
          icon: Icon(
            provider.hintMode ? Icons.lightbulb : Icons.lightbulb_outline,
            color: provider.hintMode ? Colors.yellow : null,
          ),
          onPressed: provider.toggleHintMode,
          tooltip: 'Hint Mode',
        ),
        
        // Undo button
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: provider.canUndo ? provider.undo : null,
          tooltip: 'Undo',
        ),
        
        // Redo button
        IconButton(
          icon: const Icon(Icons.redo),
          onPressed: provider.canRedo ? provider.redo : null,
          tooltip: 'Redo',
        ),
        
        // More options
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reset_view',
              child: ListTile(
                leading: Icon(Icons.center_focus_strong),
                title: Text('Reset View'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'fill_color',
              child: ListTile(
                leading: Icon(Icons.format_color_fill),
                title: Text('Fill All Selected'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'save',
              child: ListTile(
                leading: Icon(Icons.save),
                title: Text('Save Progress'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(ColoringProvider provider) {
    switch (provider.state) {
      case ColoringState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading image...'),
            ],
          ),
        );

      case ColoringState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.loadImage(widget.imageId),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case ColoringState.loaded:
      case ColoringState.completed:
        return _buildCanvas(provider);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCanvas(ColoringProvider provider) {
    final settings = context.watch<SettingsProvider>();

    return Stack(
      children: [
        // Main canvas with zoom
        ZoomContainer(
          onTransformChanged: (scale, offset) {
            provider.updateScale(scale);
            provider.updateOffset(offset);
          },
          child: Center(
            child: RepaintBoundary(
              key: _canvasKey,
              child: ColoringCanvas(
                regions: provider.regions,
                selectedColor: provider.selectedColor,
                showNumbers: settings.showNumbers || _forceShowNumbers,
                highlightSelected: settings.highlightRegions,
                hintMode: provider.hintMode,
                revealedRegionId: _revealedRegionId,
                revision: provider.revision,
                onTap: (point) => _onCanvasTap(point, provider),
                onLongPress: (point) => _onCanvasLongPress(point, provider),
              ),
            ),
          ),
        ),

        // Progress indicator
        Positioned(
          top: 16,
          left: 16,
          child: _buildProgressIndicator(provider),
        ),

        // Zoom controls
        Positioned(
          right: 16,
          bottom: 100,
          child: _buildZoomControls(provider),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ColoringProvider provider) {
    final progress = provider.progress;
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls(ColoringProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final newScale = (provider.scale * 1.2).clamp(0.5, 5.0);
              provider.updateScale(newScale);
            },
          ),
          Container(
            height: 1,
            width: 24,
            color: Colors.grey.shade300,
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              final newScale = (provider.scale / 1.2).clamp(0.5, 5.0);
              provider.updateScale(newScale);
            },
          ),
          Container(
            height: 1,
            width: 24,
            color: Colors.grey.shade300,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: provider.resetView,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColoringProvider provider) {
    if (provider.state != ColoringState.loaded &&
        provider.state != ColoringState.completed) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected color info
        if (provider.selectedColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: provider.selectedColor!.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Color ${provider.selectedColor!.number}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${provider.selectedColor!.filledRegions}/${provider.selectedColor!.totalRegions}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                if (provider.selectedColor!.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
          ),

        // Color palette
        ColorPalette(
          colors: provider.palette,
          selectedColor: provider.selectedColor,
          onColorSelected: provider.selectColor,
        ),
      ],
    );
  }

  void _handleMenuAction(String action, ColoringProvider provider) {
    switch (action) {
      case 'reset_view':
        provider.resetView();
        break;
      case 'fill_color':
        provider.fillAllWithSelectedColor();
        break;
      case 'save':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved!')),
        );
        break;
    }
  }

  void _onRegionFilled() {
    // Haptic feedback
    final settings = context.read<SettingsProvider>();
    if (settings.vibrationEnabled) {
      // Add haptic feedback here if needed
    }

    // Sound effect
    if (settings.soundEnabled) {
      // Add sound effect here if needed
    }
  }

  /// Tap on the canvas. When the selected color matches, the region is
  /// filled. Otherwise the app detects the hidden number of the tapped
  /// region, reveals it briefly and selects that color, so the next tap
  /// colors it.
  void _onCanvasTap(Offset point, ColoringProvider provider) {
    final settings = context.read<SettingsProvider>();

    final filled = provider.fillRegionAtPoint(point);
    if (filled) {
      _clearReveal();
      _onRegionFilled();
      return;
    }

    final region = provider.regionAt(point);
    if (region != null) {
      _revealRegion(region);
      provider.selectColorByNumber(region.colorNumber);

      // If user enabled auto-fill-on-detect, try to fill immediately.
      if (settings.autoFillOnDetect) {
        final filledAfterSelect = provider.fillRegionAtPoint(point);
        if (filledAfterSelect) {
          _clearReveal();
          _onRegionFilled();
        }
      }
    } else {
      _onWrongColor();
    }
  }

  /// Long-press reveals the hidden number without changing the selection.
  void _onCanvasLongPress(Offset point, ColoringProvider provider) {
    final region = provider.regionAt(point);
    if (region != null) {
      _revealRegion(region);
    }
  }

  void _revealRegion(ColorRegion region) {
    _revealTimer?.cancel();
    setState(() => _revealedRegionId = region.id);
    _revealTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _revealedRegionId = null);
      }
    });
  }

  /// Export the canvas as PNG. If numbers are being forced visible they will
  /// be included. Writes a PNG to a temporary file and shows a snackbar with
  /// the path.
  Future<void> _exportCanvasWithNumbers() async {
    try {
      // Ensure a frame with forced numbers is painted
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _canvasKey.currentContext?.findRenderObject() as ui.RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture canvas')),
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: ui.window.devicePixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final bytes = byteData.buffer.asUint8List();
      final tmpDir = Directory.systemTemp.createTempSync('happycolor_export_');
      final out = File('${tmpDir.path}/HappyColor-export.png');
      await out.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported PNG: ${out.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _clearReveal() {
    _revealTimer?.cancel();
    if (_revealedRegionId != null) {
      setState(() => _revealedRegionId = null);
    }
  }

  void _onWrongColor() {
    // Show feedback for wrong color
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tap an uncolored region to fill it'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You completed the image!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Gallery'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Share functionality can be added here
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}