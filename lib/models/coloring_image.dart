import 'dart:ui';
import 'color_region.dart';
import 'palette_color.dart';

enum ImageCategory {
  animals,
  nature,
  mandala,
  fantasy,
  places,
  food,
}

extension ImageCategoryExtension on ImageCategory {
  String get displayName {
    switch (this) {
      case ImageCategory.animals:
        return 'Animals';
      case ImageCategory.nature:
        return 'Nature';
      case ImageCategory.mandala:
        return 'Mandala';
      case ImageCategory.fantasy:
        return 'Fantasy';
      case ImageCategory.places:
        return 'Places';
      case ImageCategory.food:
        return 'Food';
    }
  }

  String get icon {
    switch (this) {
      case ImageCategory.animals:
        return '🐾';
      case ImageCategory.nature:
        return '🌿';
      case ImageCategory.mandala:
        return '🔮';
      case ImageCategory.fantasy:
        return '🦄';
      case ImageCategory.places:
        return '🏰';
      case ImageCategory.food:
        return '🍕';
    }
  }
}

class ColoringImage {
  final String id;
  final String name;
  final ImageCategory category;
  final String svgPath;
  final String thumbnailPath;
  final Size originalSize;
  List<ColorRegion> regions;
  List<PaletteColor> palette;
  bool isCompleted;
  DateTime? lastModified;

  ColoringImage({
    required this.id,
    required this.name,
    required this.category,
    required this.svgPath,
    required this.thumbnailPath,
    required this.originalSize,
    this.regions = const [],
    this.palette = const [],
    this.isCompleted = false,
    this.lastModified,
  });

  int get totalRegions => regions.length;
  
  int get filledRegions => regions.where((r) => r.isFilled).length;
  
  double get progress => totalRegions > 0 ? filledRegions / totalRegions : 0;

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'svgPath': svgPath,
      'thumbnailPath': thumbnailPath,
      'isCompleted': isCompleted ? 1 : 0,
      'lastModified': lastModified?.millisecondsSinceEpoch,
    };
  }

  // Create from database Map
  factory ColoringImage.fromMap(Map<String, dynamic> map) {
    return ColoringImage(
      id: map['id'],
      name: map['name'],
      category: ImageCategory.values[map['category']],
      svgPath: map['svgPath'],
      thumbnailPath: map['thumbnailPath'],
      originalSize: Size.zero,
      isCompleted: map['isCompleted'] == 1,
      lastModified: map['lastModified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastModified'])
          : null,
    );
  }
}