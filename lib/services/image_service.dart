import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/coloring_image.dart';
import '../models/user_progress.dart';
import 'database_service.dart';
import 'image_converter_service.dart';
import 'svg_parser_service.dart';

/// Metadata for an image imported by the user (photo -> color-by-number).
class ImportedImages {
  final String id;
  final String name;
  final String sourcePath;
  final String addedAt;

  const ImportedImages({
    required this.id,
    required this.name,
    required this.sourcePath,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': sourcePath,
        'addedAt': addedAt,
      };

  static ImportedImages fromJson(Map<String, dynamic> json) => ImportedImages(
        id: json['id'] as String,
        name: json['name'] as String,
        sourcePath: json['path'] as String,
        addedAt: (json['addedAt'] ?? '') as String,
      );
}

class ImageService {
  static final ImageService instance = ImageService._internal();
  ImageService._internal();

  final _svgParser = SvgParserService.instance;
  final _database = DatabaseService.instance;

  static const _importPrefix = 'import_';
  static const _importsDir = 'imports';
  static const _manifestFile = 'imports.json';

  // Cache for loaded images
  final Map<String, ColoringImage> _imageCache = {};

  // User-imported images, keyed by id. Persisted in a manifest next to the
  // source files so imports survive restarts.
  final Map<String, ImportedImages> _imports = {};
  bool _importsLoaded = false;

  /// Get all available images (metadata only): bundled SVGs plus imports.
  List<ColoringImageInfo> getAvailableImages() {
    return [..._builtinImages(), ..._importInfos()];
  }

  List<ColoringImageInfo> _builtinImages() {
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

  List<ColoringImageInfo> _importInfos() {
    final entries = _imports.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return entries
        .map((e) => ColoringImageInfo(
              id: e.id,
              name: e.name,
              category: ImageCategory.custom,
              svgPath: e.sourcePath,
              thumbnailPath: '',
            ))
        .toList();
  }

  /// Import an image file (PNG/JPG/WebP/GIF/BMP) and convert it into a
  /// colorless color-by-number template. The source is stored on disk and the
  /// conversion is deterministic, so saved progress keeps matching regions
  /// across restarts.
  Future<ColoringImage> importImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final id = '$_importPrefix${_fnv1aHash(bytes)}';
    await ensureImportsLoaded();

    final cached = _imageCache[id];
    if (cached != null && _imports.containsKey(id)) {
      return cached;
    }

    // Persist the source file.
    final dir = await _importsDirectory();
    await dir.create(recursive: true);
    var ext = p.extension(fileName).toLowerCase();
    if (ext.isEmpty || ext.length > 6) ext = '.png';
    final sourcePath = p.join(dir.path, '$id$ext');
    await File(sourcePath).writeAsBytes(bytes);

    final name = _displayName(fileName);
    final result = await ImageConverterService.convert(bytes: bytes);
    final image = ImageConverterService.toColoringImage(
      result,
      id: id,
      name: name,
    );

    _imageCache[id] = image;
    _imports[id] = ImportedImages(
      id: id,
      name: name,
      sourcePath: sourcePath,
      addedAt: DateTime.now().toIso8601String(),
    );
    await _saveManifest();

    return image;
  }

  /// Load a coloring image with all regions.
  Future<ColoringImage> loadImage(String imageId) async {
    await ensureImportsLoaded();

    // Check cache first
    if (_imageCache.containsKey(imageId)) {
      return _imageCache[imageId]!;
    }

    final ColoringImage image;
    if (imageId.startsWith(_importPrefix)) {
      image = await _loadImported(imageId);
    } else {
      // Find bundled image info
      final imageInfo = _builtinImages().firstWhere(
        (img) => img.id == imageId,
        orElse: () => throw Exception('Image not found: $imageId'),
      );
      // Parse SVG
      image = await _svgParser.parseSvgFile(imageInfo.svgPath, imageId);
    }

    // Load saved progress
    final progress = await _database.getProgress(imageId);
    if (progress != null) {
      _applyProgress(image, progress);
    }

    // Cache the image
    _imageCache[imageId] = image;

    return image;
  }

  Future<ColoringImage> _loadImported(String imageId) async {
    final entry = _imports[imageId];
    if (entry == null) {
      throw Exception('Imported image not found: $imageId');
    }

    final bytes = await File(entry.sourcePath).readAsBytes();
    final result = await ImageConverterService.convert(bytes: bytes);
    return ImageConverterService.toColoringImage(
      result,
      id: imageId,
      name: entry.name,
    );
  }

  Future<Directory> _importsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'HappyColor', _importsDir));
  }

  /// Load the imports manifest once per session. Safe to call repeatedly.
  Future<void> ensureImportsLoaded() async {
    if (_importsLoaded) return;
    _importsLoaded = true;
    try {
      final dir = await _importsDirectory();
      final file = File(p.join(dir.path, _manifestFile));
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        for (final item in list) {
          final entry = ImportedImages.fromJson(item as Map<String, dynamic>);
          if (await File(entry.sourcePath).exists()) {
            _imports[entry.id] = entry;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load imports manifest: $e');
    }
  }

  Future<void> _saveManifest() async {
    try {
      final dir = await _importsDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, _manifestFile));
      final list = _imports.values.map((e) => e.toJson()).toList();
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    } catch (e) {
      debugPrint('Failed to save imports manifest: $e');
    }
  }

  /// Stable FNV-1a hash so re-importing the same file reuses the same id.
  String _fnv1aHash(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    for (final b in bytes) {
      hash ^= b;
      hash *= 0x100000001b3;
    }
    return (hash & 0x7FFFFFFFFFFFFF).toRadixString(16);
  }

  String _displayName(String fileName) {
    var name = p.basenameWithoutExtension(fileName);
    name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (name.isEmpty) name = 'Imported image';
    return name[0].toUpperCase() + name.substring(1);
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
