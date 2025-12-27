import 'package:flutter/material.dart';
import '../models/coloring_image.dart';
import '../services/image_service.dart';
import '../services/database_service.dart';

class GalleryProvider extends ChangeNotifier {
  final ImageService _imageService = ImageService.instance;
  final DatabaseService _database = DatabaseService.instance;

  // State
  bool _isLoading = false;
  ImageCategory? _selectedCategory;
  String _searchQuery = '';
  GalleryFilter _filter = GalleryFilter.all;

  // Data
  List<ColoringImageInfo> _allImages = [];
  List<ColoringImageInfo> _filteredImages = [];
  Set<String> _favoriteIds = {};
  Map<String, double> _progressMap = {};

  // Getters
  bool get isLoading => _isLoading;
  ImageCategory? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  GalleryFilter get filter => _filter;
  List<ColoringImageInfo> get images => _filteredImages;
  Set<String> get favoriteIds => _favoriteIds;

  /// Initialize gallery data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load all images
      _allImages = _imageService.getAvailableImages();
      
      // Load favorites
      final favIds = await _database.getFavoriteIds();
      _favoriteIds = favIds.toSet();
      
      // Load progress
      final allProgress = await _database.getAllProgress();
      _progressMap = {
        for (var p in allProgress)
          p.imageId: p.filledRegionIds.length / 100.0 // Approximate
      };

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading gallery: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set category filter
  void setCategory(ImageCategory? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  /// Set gallery filter
  void setFilter(GalleryFilter filter) {
    _filter = filter;
    _applyFilters();
    notifyListeners();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String imageId) async {
    if (_favoriteIds.contains(imageId)) {
      await _database.removeFavorite(imageId);
      _favoriteIds.remove(imageId);
    } else {
      await _database.addFavorite(imageId);
      _favoriteIds.add(imageId);
    }
    
    if (_filter == GalleryFilter.favorites) {
      _applyFilters();
    }
    
    notifyListeners();
  }

  /// Check if image is favorite
  bool isFavorite(String imageId) {
    return _favoriteIds.contains(imageId);
  }

  /// Get progress for an image
  double getProgress(String imageId) {
    return _progressMap[imageId] ?? 0.0;
  }

  /// Apply all filters
  void _applyFilters() {
    _filteredImages = _allImages.where((image) {
      // Category filter
      if (_selectedCategory != null && image.category != _selectedCategory) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty && 
          !image.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }

      // Gallery filter
      switch (_filter) {
        case GalleryFilter.all:
          return true;
        case GalleryFilter.favorites:
          return _favoriteIds.contains(image.id);
        case GalleryFilter.inProgress:
          final progress = _progressMap[image.id] ?? 0;
          return progress > 0 && progress < 1;
        case GalleryFilter.completed:
          return (_progressMap[image.id] ?? 0) >= 1;
        case GalleryFilter.notStarted:
          return !_progressMap.containsKey(image.id) || 
                 _progressMap[image.id] == 0;
      }
    }).toList();
  }

  /// Refresh gallery data
  Future<void> refresh() async {
    await initialize();
  }

  /// Get images count by category
  Map<ImageCategory, int> getCategoryCounts() {
    final counts = <ImageCategory, int>{};
    for (final category in ImageCategory.values) {
      counts[category] = _allImages
          .where((img) => img.category == category)
          .length;
    }
    return counts;
  }
}

enum GalleryFilter {
  all,
  favorites,
  inProgress,
  completed,
  notStarted,
}

extension GalleryFilterExtension on GalleryFilter {
  String get displayName {
    switch (this) {
      case GalleryFilter.all:
        return 'All';
      case GalleryFilter.favorites:
        return 'Favorites';
      case GalleryFilter.inProgress:
        return 'In Progress';
      case GalleryFilter.completed:
        return 'Completed';
      case GalleryFilter.notStarted:
        return 'New';
    }
  }

  IconData get icon {
    switch (this) {
      case GalleryFilter.all:
        return Icons.grid_view;
      case GalleryFilter.favorites:
        return Icons.favorite;
      case GalleryFilter.inProgress:
        return Icons.hourglass_bottom;
      case GalleryFilter.completed:
        return Icons.check_circle;
      case GalleryFilter.notStarted:
        return Icons.fiber_new;
    }
  }
}