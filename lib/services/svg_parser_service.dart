import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../models/color_region.dart';
import '../models/coloring_image.dart';
import '../models/palette_color.dart';
import '../utils/path_utils.dart';
import '../utils/color_utils.dart';

class SvgParserService {
  static final SvgParserService instance = SvgParserService._internal();
  SvgParserService._internal();

  /// Parse an SVG file and return a ColoringImage
  Future<ColoringImage> parseSvgFile(String assetPath, String imageId) async {
    // Load SVG content from assets
    final svgString = await rootBundle.loadString(assetPath);
    return parseSvgString(svgString, assetPath, imageId);
  }

  /// Parse SVG string content
  ColoringImage parseSvgString(String svgString, String path, String imageId) {
    final document = XmlDocument.parse(svgString);
    final svgElement = document.rootElement;

    // Get SVG dimensions
    final width = _parseDouble(svgElement.getAttribute('width') ?? '500');
    final height = _parseDouble(svgElement.getAttribute('height') ?? '500');
    final originalSize = Size(width, height);

    // Parse all path elements
    final regions = <ColorRegion>[];
    final colorMap = <Color, int>{};
    int colorCounter = 1;
    int regionId = 0;

    _parseElement(svgElement, regions, colorMap, colorCounter, regionId, 
        (newColorCounter, newRegionId) {
      colorCounter = newColorCounter;
      regionId = newRegionId;
    });

    // Create palette from color map
    final palette = _createPalette(colorMap, regions);

    return ColoringImage(
      id: imageId,
      name: _extractName(path),
      category: ImageCategory.animals, // Default, can be set later
      svgPath: path,
      thumbnailPath: path.replaceAll('.svg', '_thumb.png'),
      originalSize: originalSize,
      regions: regions,
      palette: palette,
    );
  }

  void _parseElement(
    XmlElement element,
    List<ColorRegion> regions,
    Map<Color, int> colorMap,
    int colorCounter,
    int regionId,
    Function(int, int) updateCounters,
  ) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local == 'path') {
        final pathData = child.getAttribute('d');
        if (pathData != null && pathData.isNotEmpty) {
          // Parse color from fill attribute or style
          final color = _parseColor(child);
          
          // Assign color number
          if (!colorMap.containsKey(color)) {
            colorMap[color] = colorCounter;
            colorCounter++;
          }

          // Parse the path
          final path = PathUtils.parseSvgPath(pathData);
          final centerPoint = PathUtils.getCenterPoint(path);

          regions.add(ColorRegion(
            id: regionId,
            path: path,
            colorNumber: colorMap[color]!,
            targetColor: color,
            centerPoint: centerPoint,
            isFilled: false,
          ));
          
          regionId++;
        }
      } else if (child.name.local == 'g' || 
                 child.name.local == 'svg') {
        // Recursively parse groups
        _parseElement(child, regions, colorMap, colorCounter, regionId, 
            updateCounters);
      } else if (child.name.local == 'rect') {
        // Parse rectangle elements
        final region = _parseRect(child, colorMap, colorCounter, regionId);
        if (region != null) {
          if (!colorMap.containsKey(region.targetColor)) {
            colorMap[region.targetColor] = colorCounter;
            colorCounter++;
          }
          regions.add(region);
          regionId++;
        }
      } else if (child.name.local == 'circle') {
        // Parse circle elements
        final region = _parseCircle(child, colorMap, colorCounter, regionId);
        if (region != null) {
          if (!colorMap.containsKey(region.targetColor)) {
            colorMap[region.targetColor] = colorCounter;
            colorCounter++;
          }
          regions.add(region);
          regionId++;
        }
      } else if (child.name.local == 'ellipse') {
        // Parse ellipse elements
        final region = _parseEllipse(child, colorMap, colorCounter, regionId);
        if (region != null) {
          if (!colorMap.containsKey(region.targetColor)) {
            colorMap[region.targetColor] = colorCounter;
            colorCounter++;
          }
          regions.add(region);
          regionId++;
        }
      } else if (child.name.local == 'polygon') {
        // Parse polygon elements
        final region = _parsePolygon(child, colorMap, colorCounter, regionId);
        if (region != null) {
          if (!colorMap.containsKey(region.targetColor)) {
            colorMap[region.targetColor] = colorCounter;
            colorCounter++;
          }
          regions.add(region);
          regionId++;
        }
      }
    }
    
    updateCounters(colorCounter, regionId);
  }

  ColorRegion? _parseRect(XmlElement element, Map<Color, int> colorMap, 
      int colorCounter, int regionId) {
    final x = _parseDouble(element.getAttribute('x') ?? '0');
    final y = _parseDouble(element.getAttribute('y') ?? '0');
    final width = _parseDouble(element.getAttribute('width') ?? '0');
    final height = _parseDouble(element.getAttribute('height') ?? '0');
    
    if (width <= 0 || height <= 0) return null;

    final color = _parseColor(element);
    final path = Path()..addRect(Rect.fromLTWH(x, y, width, height));
    
    return ColorRegion(
      id: regionId,
      path: path,
      colorNumber: colorMap[color] ?? colorCounter,
      targetColor: color,
      centerPoint: Offset(x + width / 2, y + height / 2),
      isFilled: false,
    );
  }

  ColorRegion? _parseCircle(XmlElement element, Map<Color, int> colorMap,
      int colorCounter, int regionId) {
    final cx = _parseDouble(element.getAttribute('cx') ?? '0');
    final cy = _parseDouble(element.getAttribute('cy') ?? '0');
    final r = _parseDouble(element.getAttribute('r') ?? '0');
    
    if (r <= 0) return null;

    final color = _parseColor(element);
    final path = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    
    return ColorRegion(
      id: regionId,
      path: path,
      colorNumber: colorMap[color] ?? colorCounter,
      targetColor: color,
      centerPoint: Offset(cx, cy),
      isFilled: false,
    );
  }

  ColorRegion? _parseEllipse(XmlElement element, Map<Color, int> colorMap,
      int colorCounter, int regionId) {
    final cx = _parseDouble(element.getAttribute('cx') ?? '0');
    final cy = _parseDouble(element.getAttribute('cy') ?? '0');
    final rx = _parseDouble(element.getAttribute('rx') ?? '0');
    final ry = _parseDouble(element.getAttribute('ry') ?? '0');
    
    if (rx <= 0 || ry <= 0) return null;

    final color = _parseColor(element);
    final path = Path()..addOval(Rect.fromCenter(
      center: Offset(cx, cy), 
      width: rx * 2, 
      height: ry * 2,
    ));
    
    return ColorRegion(
      id: regionId,
      path: path,
      colorNumber: colorMap[color] ?? colorCounter,
      targetColor: color,
      centerPoint: Offset(cx, cy),
      isFilled: false,
    );
  }

  ColorRegion? _parsePolygon(XmlElement element, Map<Color, int> colorMap,
      int colorCounter, int regionId) {
    final pointsStr = element.getAttribute('points');
    if (pointsStr == null || pointsStr.isEmpty) return null;

    final points = _parsePoints(pointsStr);
    if (points.length < 3) return null;

    final color = _parseColor(element);
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    
    return ColorRegion(
      id: regionId,
      path: path,
      colorNumber: colorMap[color] ?? colorCounter,
      targetColor: color,
      centerPoint: PathUtils.getCenterPoint(path),
      isFilled: false,
    );
  }

  List<Offset> _parsePoints(String pointsStr) {
    final points = <Offset>[];
    final pairs = pointsStr.trim().split(RegExp(r'[\s,]+'));
    
    for (int i = 0; i < pairs.length - 1; i += 2) {
      final x = double.tryParse(pairs[i]) ?? 0;
      final y = double.tryParse(pairs[i + 1]) ?? 0;
      points.add(Offset(x, y));
    }
    
    return points;
  }

  Color _parseColor(XmlElement element) {
    // Try fill attribute first
    var fillStr = element.getAttribute('fill');
    
    // Try style attribute
    if (fillStr == null || fillStr == 'none') {
      final style = element.getAttribute('style');
      if (style != null) {
        final match = RegExp(r'fill:\s*([^;]+)').firstMatch(style);
        if (match != null) {
          fillStr = match.group(1)?.trim();
        }
      }
    }

    // Default gray if no fill
    if (fillStr == null || fillStr == 'none' || fillStr.isEmpty) {
      return const Color(0xFF808080);
    }

    return _parseColorString(fillStr);
  }

  Color _parseColorString(String colorStr) {
    colorStr = colorStr.trim().toLowerCase();

    // Handle hex colors
    if (colorStr.startsWith('#')) {
      return ColorUtils.fromHex(colorStr);
    }

    // Handle rgb() format
    if (colorStr.startsWith('rgb')) {
      final match = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(colorStr);
      if (match != null) {
        return Color.fromRGBO(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          1.0,
        );
      }
    }

    // Handle named colors
    return _namedColors[colorStr] ?? const Color(0xFF808080);
  }

  List<PaletteColor> _createPalette(Map<Color, int> colorMap, List<ColorRegion> regions) {
    return colorMap.entries.map((entry) {
      final totalRegions = regions.where((r) => r.colorNumber == entry.value).length;
      return PaletteColor(
        number: entry.value,
        color: entry.key,
        totalRegions: totalRegions,
      );
    }).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  double _parseDouble(String value) {
    // Remove units like 'px', 'pt', etc.
    final numStr = value.replaceAll(RegExp(r'[a-zA-Z%]'), '');
    return double.tryParse(numStr) ?? 0;
  }

  String _extractName(String path) {
    final fileName = path.split('/').last;
    return fileName.replaceAll('.svg', '').replaceAll('_', ' ');
  }

  static const Map<String, Color> _namedColors = {
    'red': Color(0xFFFF0000),
    'green': Color(0xFF00FF00),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'orange': Color(0xFFFFA500),
    'purple': Color(0xFF800080),
    'pink': Color(0xFFFFC0CB),
    'brown': Color(0xFFA52A2A),
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'cyan': Color(0xFF00FFFF),
    'magenta': Color(0xFFFF00FF),
    'lime': Color(0xFF00FF00),
    'navy': Color(0xFF000080),
    'teal': Color(0xFF008080),
    'maroon': Color(0xFF800000),
    'olive': Color(0xFF808000),
    'aqua': Color(0xFF00FFFF),
    'silver': Color(0xFFC0C0C0),
  };
}