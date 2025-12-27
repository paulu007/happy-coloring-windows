import '../models/coloring_image.dart';
import '../models/user_progress.dart';
import 'database_service.dart';
import 'svg_parser_service.dart';

class ImageService {
  static final ImageService instance = ImageService._internal();
  ImageService._internal();

  final _svgParser = SvgParserService.instance;
  final _database = DatabaseService.instance;

  // Cache for loaded images
  final Map<String, ColoringImage> _imageCache = {};

  /// Get all available images (metadata only)
  List<ColoringImageInfo> getAvailableImages() {
    // In a real app, this would come from a database or API
    return [
      ColoringImageInfo(
        id: 'butterfly_1',
        name: 'Beautiful Butterfly',
        category: ImageCategory.animals,
        svgPath: 'assets/svg/butterfly.svg',
        thumbnailPath: 'assets/images/butterfly_thumb.png',
      ),
      ColoringImageInfo(
        id: 'flower_1',
        name: 'Spring Flower',
        category: ImageCategory.nature,
        svgPath: 'assets/svg/flower.svg',
        thumbnailPath: 'assets/images/flower_thumb.png',
      ),
      ColoringImageInfo(
        id: 'mandala_1',
        name: 'Peace Mandala',
        category: ImageCategory.mandala,
        svgPath: 'assets/svg/mandala.svg',
        thumbnailPath: 'assets/images/mandala_thumb.png',
      ),
      // Add more images here
    ];
  }

  /// Load a coloring image with all regions
  Future<ColoringImage> loadImage(String imageId) async {
    // Check cache first
    if (_imageCache.containsKey(imageId)) {
      return _imageCache[imageId]!;
    }

    // Find image info
    final imageInfo = getAvailableImages().firstWhere(
      (img) => img.id == imageId,
      orElse: () => throw Exception('Image not found: $imageId'),
    );

    // Parse SVG
    final image = await _svgParser.parseSvgFile(imageInfo.svgPath, imageId);

    // Load saved progress
    final progress = await _database.getProgress(imageId);
    if (progress != null) {
      _applyProgress(image, progress);
    }

    // Cache the image
    _imageCache[imageId] = image;

    return image;
  }

  /// Apply saved progress to image
  void _applyProgress(ColoringImage image, UserProgress progress) {
    for (final region in image.regions) {
      if (progress.filledRegionIds.contains(region.id)) {
        region.isFilled = true;
      }
    }

    // Update palette filled counts
    for (final paletteColor in image.palette) {
      paletteColor.filledRegions = image.regions
          .where((r) => r.colorNumber == paletteColor.number && r.isFilled)
          .length;
    }

    image.isCompleted = progress.isCompleted;
    image.lastModified = progress.lastModified;
  }

  /// Save progress for an image
  Future<void> saveProgress(ColoringImage image) async {
    final filledIds = image.regions
        .where((r) => r.isFilled)
        .map((r) => r.id)
        .toList();

    final progress = UserProgress(
      imageId: image.id,
      filledRegionIds: filledIds,
      lastModified: DateTime.now(),
      isCompleted: image.progress >= 1.0,
    );

    await _database.saveProgress(progress);
    image.lastModified = progress.lastModified;
    image.isCompleted = progress.isCompleted;
  }

  /// Get images by category
  List<ColoringImageInfo> getImagesByCategory(ImageCategory category) {
    return getAvailableImages()
        .where((img) => img.category == category)
        .toList();
  }

  /// Get in-progress images
  Future<List<ColoringImageInfo>> getInProgressImages() async {
    final allProgress = await _database.getAllProgress();
    final inProgressIds = allProgress
        .where((p) => !p.isCompleted && p.filledRegionIds.isNotEmpty)
        .map((p) => p.imageId)
        .toSet();

    return getAvailableImages()
        .where((img) => inProgressIds.contains(img.id))
        .toList();
  }

  /// Get completed images
  Future<List<ColoringImageInfo>> getCompletedImages() async {
    final allProgress = await _database.getAllProgress();
    final completedIds = allProgress
        .where((p) => p.isCompleted)
        .map((p) => p.imageId)
        .toSet();

    return getAvailableImages()
        .where((img) => completedIds.contains(img.id))
        .toList();
  }

  /// Clear cache
  void clearCache() {
    _imageCache.clear();
  }
}

/// Lightweight image info for gallery display
class ColoringImageInfo {
  final String id;
  final String name;
  final ImageCategory category;
  final String svgPath;
  final String thumbnailPath;

  ColoringImageInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.svgPath,
    required this.thumbnailPath,
  });
}