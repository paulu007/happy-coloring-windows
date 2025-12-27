import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/color_region.dart';
import '../models/coloring_image.dart';
import '../models/palette_color.dart';
import '../services/image_service.dart';

enum ColoringState {
  initial,
  loading,
  loaded,
  error,
  completed,
}

class ColoringProvider extends ChangeNotifier {
  final ImageService _imageService = ImageService.instance;

  // State
  ColoringState _state = ColoringState.initial;
  ColoringImage? _currentImage;
  PaletteColor? _selectedColor;
  String? _errorMessage;

  // Undo/Redo stacks
  final List<int> _undoStack = [];
  final List<int> _redoStack = [];

  // Zoom and Pan
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Hint mode
  bool _hintMode = false;

  // Getters
  ColoringState get state => _state;
  ColoringImage? get currentImage => _currentImage;
  PaletteColor? get selectedColor => _selectedColor;
  String? get errorMessage => _errorMessage;
  double get scale => _scale;
  Offset get offset => _offset;
  bool get hintMode => _hintMode;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  double get progress => _currentImage?.progress ?? 0;
  bool get isCompleted => _currentImage?.isCompleted ?? false;

  List<ColorRegion> get regions => _currentImage?.regions ?? [];
  List<PaletteColor> get palette => _currentImage?.palette ?? [];

  /// Load an image for coloring
  Future<void> loadImage(String imageId) async {
    _state = ColoringState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentImage = await _imageService.loadImage(imageId);
      _selectedColor = _currentImage!.palette.isNotEmpty 
          ? _currentImage!.palette.first 
          : null;
      
      // Reset view
      _scale = 1.0;
      _offset = Offset.zero;
      _undoStack.clear();
      _redoStack.clear();
      
      _state = ColoringState.loaded;
    } catch (e) {
      _state = ColoringState.error;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  /// Select a color from palette
  void selectColor(PaletteColor color) {
    _selectedColor = color;
    notifyListeners();
  }

  /// Select color by number
  void selectColorByNumber(int number) {
    final color = palette.firstWhere(
      (c) => c.number == number,
      orElse: () => palette.first,
    );
    selectColor(color);
  }

  /// Handle tap on canvas - fill region if correct color
  bool fillRegionAtPoint(Offset point) {
    if (_currentImage == null || _selectedColor == null) return false;

    // Find the region at this point
    for (int i = _currentImage!.regions.length - 1; i >= 0; i--) {
      final region = _currentImage!.regions[i];
      
      if (!region.isFilled && region.containsPoint(point)) {
        // Check if correct color is selected
        if (region.colorNumber == _selectedColor!.number) {
          // Fill the region
          region.isFilled = true;
          
          // Update palette
          _selectedColor!.filledRegions++;
          
          // Add to undo stack
          _undoStack.add(region.id);
          _redoStack.clear();
          
          // Check if completed
          _checkCompletion();
          
          // Auto-save progress
          _saveProgress();
          
          notifyListeners();
          return true;
        } else {
          // Wrong color - return false (can show feedback)
          return false;
        }
      }
    }
    
    return false;
  }

  /// Fill all regions with selected color (for hint/auto-fill)
  void fillAllWithSelectedColor() {
    if (_currentImage == null || _selectedColor == null) return;

    final regionsToFill = _currentImage!.regions
        .where((r) => !r.isFilled && r.colorNumber == _selectedColor!.number)
        .toList();

    for (final region in regionsToFill) {
      region.isFilled = true;
      _undoStack.add(region.id);
    }

    _selectedColor!.filledRegions = _currentImage!.regions
        .where((r) => r.colorNumber == _selectedColor!.number && r.isFilled)
        .length;

    _redoStack.clear();
    _checkCompletion();
    _saveProgress();
    notifyListeners();
  }

  /// Undo last fill
  void undo() {
    if (_undoStack.isEmpty || _currentImage == null) return;

    final regionId = _undoStack.removeLast();
    final region = _currentImage!.regions.firstWhere((r) => r.id == regionId);
    
    region.isFilled = false;
    
    // Update palette
    final paletteColor = palette.firstWhere((p) => p.number == region.colorNumber);
    paletteColor.filledRegions--;
    
    _redoStack.add(regionId);
    _currentImage!.isCompleted = false;
    
    _saveProgress();
    notifyListeners();
  }

  /// Redo last undone fill
  void redo() {
    if (_redoStack.isEmpty || _currentImage == null) return;

    final regionId = _redoStack.removeLast();
    final region = _currentImage!.regions.firstWhere((r) => r.id == regionId);
    
    region.isFilled = true;
    
    // Update palette
    final paletteColor = palette.firstWhere((p) => p.number == region.colorNumber);
    paletteColor.filledRegions++;
    
    _undoStack.add(regionId);
    
    _checkCompletion();
    _saveProgress();
    notifyListeners();
  }

  /// Toggle hint mode
  void toggleHintMode() {
    _hintMode = !_hintMode;
    notifyListeners();
  }

  /// Update zoom scale
  void updateScale(double newScale) {
    _scale = newScale.clamp(0.5, 5.0);
    notifyListeners();
  }

  /// Update pan offset
  void updateOffset(Offset newOffset) {
    _offset = newOffset;
    notifyListeners();
  }

  /// Reset zoom and pan
  void resetView() {
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Get regions that match selected color (for highlighting)
  List<ColorRegion> getHighlightedRegions() {
    if (_selectedColor == null || _currentImage == null) return [];
    
    return _currentImage!.regions
        .where((r) => !r.isFilled && r.colorNumber == _selectedColor!.number)
        .toList();
  }

  /// Check if all regions are filled
  void _checkCompletion() {
    if (_currentImage == null) return;
    
    final allFilled = _currentImage!.regions.every((r) => r.isFilled);
    if (allFilled && !_currentImage!.isCompleted) {
      _currentImage!.isCompleted = true;
      _state = ColoringState.completed;
    }
  }

  /// Save progress to database
  Future<void> _saveProgress() async {
    if (_currentImage == null) return;
    await _imageService.saveProgress(_currentImage!);
  }

  /// Clear current image
  void clear() {
    _currentImage = null;
    _selectedColor = null;
    _state = ColoringState.initial;
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _saveProgress();
    super.dispose();
  }
}