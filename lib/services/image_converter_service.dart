import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/coloring_image.dart';
import '../models/color_region.dart';
import '../models/palette_color.dart';

/// Options for converting a raster image into a color-by-number template.
class ConverterOptions {
  /// Maximum number of distinct colors in the generated palette.
  final int maxColors;

  /// Largest dimension (width or height) of the working image. The source is
  /// downscaled to roughly this size before segmentation, which keeps both
  /// conversion time and region count sane.
  final int maxDimension;

  /// Regions with fewer pixels than this are absorbed into their largest
  /// neighboring region, removing specks that are impossible to tap.
  final int minRegionArea;

  /// Number of 3x3 majority-filter passes applied before segmentation to
  /// remove pixel noise.
  final int smoothingPasses;

  const ConverterOptions({
    this.maxColors = 16,
    this.maxDimension = 360,
    this.minRegionArea = 16,
    this.smoothingPasses = 2,
  });
}

/// Result of the pure (isolate-safe) conversion pipeline. Contains only
/// plain data - the [Path] objects are built on the main isolate.
class ConvertResult {
  final int width;
  final int height;
  final List<int> palette; // 0xAARRGGBB, alpha always FF
  final List<RegionRuns> regions;

  const ConvertResult({
    required this.width,
    required this.height,
    required this.palette,
    required this.regions,
  });
}

/// A segmented region as horizontal runs of pixels: [y, x0, x1, y, x0, x1,
/// ...] with x1 inclusive.
class RegionRuns {
  final int paletteIndex;
  final Int32List runs;
  final int area;
  final double centroidX;
  final double centroidY;

  const RegionRuns({
    required this.paletteIndex,
    required this.runs,
    required this.area,
    required this.centroidX,
    required this.centroidY,
  });
}

/// Converts raster images (PNG/JPG/WebP/GIF/BMP) into a colorless
/// color-by-number template.
///
/// The heavy work (decode, downscale, quantize, smooth, segment) runs inside
/// a background isolate via [compute]; only the cheap [Path] assembly happens
/// on the UI isolate. The pipeline is fully deterministic: the same input
/// bytes always produce the same regions and numbers, which is what makes
/// saved progress re-appliable after re-converting an imported image.
class ImageConverterService {
  static Future<ConvertResult> convert({
    required Uint8List bytes,
    ConverterOptions options = const ConverterOptions(),
  }) {
    return compute(_convertInIsolate, _ConvertRequest(bytes, options));
  }

  /// Build a ready-to-color [ColoringImage] from a conversion result.
  static ColoringImage toColoringImage(
    ConvertResult result, {
    required String id,
    required String name,
  }) {
    final regions = <ColorRegion>[];
    for (var i = 0; i < result.regions.length; i++) {
      final r = result.regions[i];
      final path = Path();
      for (var j = 0; j < r.runs.length; j += 3) {
        final y = r.runs[j].toDouble();
        final x0 = r.runs[j + 1].toDouble();
        final x1 = r.runs[j + 2] + 1.0;
        path.addRect(Rect.fromLTRB(x0, y, x1, y + 1.0));
      }
      regions.add(ColorRegion(
        id: i,
        path: path,
        colorNumber: r.paletteIndex + 1,
        targetColor: Color(result.palette[r.paletteIndex]),
        centerPoint: Offset(r.centroidX, r.centroidY),
        isFilled: false,
      ));
    }

    final palette = <PaletteColor>[];
    for (var i = 0; i < result.palette.length; i++) {
      final number = i + 1;
      final total =
          regions.where((r) => r.colorNumber == number).length;
      palette.add(PaletteColor(
        number: number,
        color: Color(result.palette[i]),
        totalRegions: total,
      ));
    }

    return ColoringImage(
      id: id,
      name: name,
      category: ImageCategory.custom,
      svgPath: '',
      thumbnailPath: '',
      originalSize: Size(result.width.toDouble(), result.height.toDouble()),
      regions: regions,
      palette: palette,
    );
  }
}

// ---------------------------------------------------------------------------
// Isolate pipeline
// ---------------------------------------------------------------------------

class _ConvertRequest {
  final Uint8List bytes;
  final ConverterOptions options;
  const _ConvertRequest(this.bytes, this.options);
}

ConvertResult _convertInIsolate(_ConvertRequest request) {
  final options = request.options;
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupted image file');
  }

  // 1. Downscale so the largest side is at most maxDimension.
  final longest = math.max(decoded.width, decoded.height);
  var working = decoded;
  if (longest > options.maxDimension) {
    final ratio = options.maxDimension / longest;
    working = img.copyResize(
      decoded,
      width: math.max(1, (decoded.width * ratio).round()),
      height: math.max(1, (decoded.height * ratio).round()),
      interpolation: img.Interpolation.average,
    );
  }

  final width = working.width;
  final height = working.height;
  final pixelCount = width * height;

  // 2. Flatten to opaque 0xRRGGBB pixels (composite over white).
  final pixels = Uint32List(pixelCount);
  var i = 0;
  for (final p in working) {
    final a = (p.a * 255).round().clamp(0, 255);
    final r = ((p.r * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    final g = ((p.g * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    final b = ((p.b * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    pixels[i++] = (r << 16) | (g << 8) | b;
  }

  // 3. Quantize to a small palette and map every pixel to its nearest color.
  final maxColors = options.maxColors.clamp(2, 48).toInt();
  final palette = MedianCutQuantizer.quantize(pixels, maxColors);
  var indices = NearestColorMapper.map(pixels, palette);

  // 4. Remove noise with majority filtering before segmentation.
  for (var pass = 0; pass < options.smoothingPasses; pass++) {
    indices = MajoritySmoother.smooth(indices, palette.length, width, height);
  }

  // 5. Segment into connected regions, absorbing specks that are too small
  //    to tap comfortably.
  final built = RegionBuilder.build(
    indices,
    palette,
    width,
    height,
    minRegionArea: options.minRegionArea,
  );

  return ConvertResult(
    width: width,
    height: height,
    palette: built.palette,
    regions: built.regions,
  );
}

// ---------------------------------------------------------------------------
// Median cut quantization
// ---------------------------------------------------------------------------

/// Deterministic median-cut color quantizer over opaque 0xRRGGBB pixels.
class MedianCutQuantizer {
  /// Returns up to [maxColors] colors as 0xFFrrggbb ints, ordered by
  /// significance (most common / widest boxes first).
  static List<int> quantize(Uint32List pixels, int maxColors) {
    if (pixels.isEmpty) return const [];

    final px = pixels.toList();
    final boxes = <_Box>[_Box(0, px.length)];

    while (boxes.length < maxColors) {
      // Pick the splittable box with the largest color range; ties are
      // broken by pixel count so the result is deterministic.
      _Box? best;
      _BoxInfo? bestInfo;
      var bestCount = 0;
      for (final box in boxes) {
        final info = _boxInfo(px, box);
        if (info.range <= 0 || box.count() < 2) continue;
        if (bestInfo == null ||
            info.range > bestInfo.range ||
            (info.range == bestInfo.range && box.count() > bestCount)) {
          best = box;
          bestInfo = info;
          bestCount = box.count();
        }
      }
      if (best == null || bestInfo == null) break;

      final mid = best.start + (best.end - best.start) ~/ 2;
      final shift =
          bestInfo.channel == 0 ? 16 : bestInfo.channel == 1 ? 8 : 0;
      final sub = px.sublist(best.start, best.end)
        ..sort((a, b) => ((a >> shift) & 0xFF) - ((b >> shift) & 0xFF));
      px.setRange(best.start, best.end, sub);

      boxes.remove(best);
      boxes
        ..add(_Box(best.start, mid))
        ..add(_Box(mid, best.end));
    }

    // Average color of each box.
    return boxes.where((b) => b.count() > 0).map((box) {
      var r = 0, g = 0, b = 0;
      for (var i = box.start; i < box.end; i++) {
        final p = px[i];
        r += (p >> 16) & 0xFF;
        g += (p >> 8) & 0xFF;
        b += p & 0xFF;
      }
      final n = box.count();
      return 0xFF000000 | ((r ~/ n) << 16) | ((g ~/ n) << 8) | (b ~/ n);
    }).toList();
  }
}

class _Box {
  final int start;
  final int end;
  const _Box(this.start, this.end);
  int count() => end - start;
}

class _BoxInfo {
  final int channel; // 0=r, 1=g, 2=b
  final int range;
  const _BoxInfo(this.channel, this.range);
}

_BoxInfo _boxInfo(List<int> px, _Box box) {
  var minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;
  for (var i = box.start; i < box.end; i++) {
    final p = px[i];
    final r = (p >> 16) & 0xFF;
    final g = (p >> 8) & 0xFF;
    final b = p & 0xFF;
    if (r < minR) minR = r;
    if (r > maxR) maxR = r;
    if (g < minG) minG = g;
    if (g > maxG) maxG = g;
    if (b < minB) minB = b;
    if (b > maxB) maxB = b;
  }
  final ranges = [maxR - minR, maxG - minG, maxB - minB];
  var channel = 0;
  if (ranges[1] > ranges[channel]) channel = 1;
  if (ranges[2] > ranges[channel]) channel = 2;
  return _BoxInfo(channel, ranges[channel]);
}

// ---------------------------------------------------------------------------
// Nearest-color mapping
// ---------------------------------------------------------------------------

class NearestColorMapper {
  /// Maps every pixel to the index of its nearest palette color. Distance is
  /// weighted (2R, 4G, 3B) which approximates human perception.
  static Uint8List map(Uint32List pixels, List<int> palette) {
    final out = Uint8List(pixels.length);
    for (var i = 0; i < pixels.length; i++) {
      out[i] = nearest(pixels[i], palette);
    }
    return out;
  }

  static int nearest(int pixel, List<int> palette) {
    final r = (pixel >> 16) & 0xFF;
    final g = (pixel >> 8) & 0xFF;
    final b = pixel & 0xFF;
    var best = 0;
    var bestDist = 1 << 30;
    for (var j = 0; j < palette.length; j++) {
      final c = palette[j];
      final dr = r - ((c >> 16) & 0xFF);
      final dg = g - ((c >> 8) & 0xFF);
      final db = b - (c & 0xFF);
      final dist = dr * dr * 2 + dg * dg * 4 + db * db * 3;
      if (dist < bestDist) {
        bestDist = dist;
        best = j;
      }
    }
    return best;
  }
}

// ---------------------------------------------------------------------------
// Majority smoothing
// ---------------------------------------------------------------------------

class MajoritySmoother {
  /// One 3x3 mode filter pass: each pixel becomes the most common palette
  /// index in its neighborhood (ties keep the current value, so the pass is
  /// deterministic).
  static Uint8List smooth(
      Uint8List indices, int paletteLength, int width, int height) {
    final counts = List<int>.filled(paletteLength, 0);
    final out = Uint8List(indices.length);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        for (var c = 0; c < paletteLength; c++) {
          counts[c] = 0;
        }
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            counts[indices[ny * width + nx]]++;
          }
        }
        var best = indices[i];
        var bestCount = counts[best];
        for (var c = 0; c < paletteLength; c++) {
          if (counts[c] > bestCount) {
            best = c;
            bestCount = counts[c];
          }
        }
        out[i] = best;
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Region segmentation
// ---------------------------------------------------------------------------

class _RegionBuildOutput {
  final List<int> palette; // renumbered, only used colors, 0xFFrrggbb
  final List<RegionRuns> regions;
  const _RegionBuildOutput(this.palette, this.regions);
}

/// Segments the palette-index grid into 4-connected regions of equal color,
/// absorbs regions below [minRegionArea] into their largest neighbor, and
/// emits horizontal pixel runs per region.
class RegionBuilder {
  static _RegionBuildOutput build(
    Uint8List indices,
    List<int> palette,
    int width,
    int height, {
    required int minRegionArea,
    int maxRegions = 2500,
  }) {
    final labels = _label(indices, width, height);
    final labelCount = labels.reduce((a, b) => a > b ? a : b) + 1;

    // The color each original label started with; roots always refer to one
    // of these original labels, so this lookup stays valid after merges.
    final originalColor = List<int>.filled(labelCount, 0);
    var seen = List<bool>.filled(labelCount, false);
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i];
      if (!seen[l]) {
        seen[l] = true;
        originalColor[l] = indices[i];
      }
    }

    // Absorb small regions, raising the threshold when the image is so
    // textured that the region count still explodes.
    var threshold = minRegionArea;
    while (true) {
      _absorbSmall(labels, labelCount, width, threshold);
      final count = _distinctLabels(labels);
      if (count <= maxRegions || threshold >= 4096) break;
      threshold *= 2;
    }

    // Dense palette numbering and region ids in first-appearance (scan)
    // order, so both are fully deterministic.
    final numberByColor = <int, int>{};
    final newPalette = <int>[];
    final regionIds = <int, int>{};
    final regionColor = <int>[];
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i];
      if (regionIds.containsKey(l)) continue;
      regionIds[l] = regionColor.length;
      final color = originalColor[l];
      regionColor.add(color);
      if (!numberByColor.containsKey(color)) {
        numberByColor[color] = newPalette.length;
        newPalette.add(palette[color]);
      }
    }

    // Build horizontal runs per region.
    final regions = List<RegionRuns?>.filled(regionColor.length, null);
    for (var y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        final start = x;
        final label = labels[y * width + x];
        while (x < width && labels[y * width + x] == label) {
          x++;
        }
        _appendRun(
            regions, regionIds[label]!, regionColor[regionIds[label]!], y, start, x - 1);
      }
    }

    final mapped = regions.whereType<RegionRuns>().map((r) => RegionRuns(
          paletteIndex: numberByColor[r.paletteIndex]!,
          runs: r.runs,
          area: r.area,
          centroidX: r.centroidX,
          centroidY: r.centroidY,
        )).toList();

    return _RegionBuildOutput(newPalette, mapped);
  }

  static void _appendRun(List<RegionRuns?> regions, int region,
      int originalColor, int y, int x0, int x1) {
    final length = x1 - x0 + 1;
    final existing = regions[region];
    if (existing == null) {
      final runs = Int32List(3)
        ..[0] = y
        ..[1] = x0
        ..[2] = x1;
      regions[region] = RegionRuns(
        paletteIndex: originalColor,
        runs: runs,
        area: length,
        centroidX: (x0 + x1 + 1) / 2,
        centroidY: y.toDouble(),
      );
      return;
    }
    final old = existing.runs;
    final next = Int32List(old.length + 3);
    next.setAll(0, old);
    next[old.length] = y;
    next[old.length + 1] = x0;
    next[old.length + 2] = x1;
    final n = existing.area + length;
    regions[region] = RegionRuns(
      paletteIndex: existing.paletteIndex,
      runs: next,
      area: n,
      centroidX:
          (existing.centroidX * existing.area + (x0 + x1 + 1) / 2 * length) / n,
      centroidY: (existing.centroidY * existing.area + y * length) / n,
    );
  }

  /// 4-connected component labeling. Returns labels (>= 0) per pixel.
  static Int32List _label(Uint8List indices, int width, int height) {
    final total = width * height;
    final labels = Int32List(total)..fillRange(0, total, -1);
    final stack = Int32List(total);
    var next = 0;
    for (var i = 0; i < total; i++) {
      if (labels[i] != -1) continue;
      final color = indices[i];
      var sp = 0;
      stack[sp++] = i;
      labels[i] = next;
      while (sp > 0) {
        final p = stack[--sp];
        final x = p % width;
        if (x > 0 && labels[p - 1] == -1 && indices[p - 1] == color) {
          labels[p - 1] = next;
          stack[sp++] = p - 1;
        }
        if (x < width - 1 && labels[p + 1] == -1 && indices[p + 1] == color) {
          labels[p + 1] = next;
          stack[sp++] = p + 1;
        }
        if (p >= width && labels[p - width] == -1 && indices[p - width] == color) {
          labels[p - width] = next;
          stack[sp++] = p - width;
        }
        if (p + width < total &&
            labels[p + width] == -1 &&
            indices[p + width] == color) {
          labels[p + width] = next;
          stack[sp++] = p + width;
        }
      }
      next++;
    }
    return labels;
  }

  static int _distinctLabels(Int32List labels) {
    final seen = <int>{};
    for (final l in labels) {
      seen.add(l);
    }
    return seen.length;
  }

  /// Merges every region smaller than [threshold] pixels into its largest
  /// adjacent region, using union-find over labels and a single pixel
  /// grouping pass (no grid rescans per merge).
  static void _absorbSmall(
      Int32List labels, int labelCount, int width, int threshold) {
    // Group pixel indexes by their current label via counting sort.
    final areas = Int32List(labelCount);
    for (final l in labels) {
      areas[l]++;
    }
    final offsets = Int32List(labelCount + 1);
    for (var l = 0; l < labelCount; l++) {
      offsets[l + 1] = offsets[l] + areas[l];
    }
    final cursor = offsets.sublist(0, labelCount);
    final pixelsByLabel = Int32List(labels.length);
    for (var i = 0; i < labels.length; i++) {
      pixelsByLabel[cursor[labels[i]]++] = i;
    }

    final parent = Int32List(labelCount);
    for (var l = 0; l < labelCount; l++) {
      parent[l] = l;
    }
    final rootArea = Int32List.fromList(areas);

    int find(int l) {
      var root = l;
      while (parent[root] != root) {
        root = parent[root];
      }
      while (parent[l] != root) {
        final next = parent[l];
        parent[l] = root;
        l = next;
      }
      return root;
    }

    var changed = true;
    while (changed) {
      changed = false;
      for (var l = 0; l < labelCount; l++) {
        if (areas[l] == 0) continue;
        final root = find(l);
        if (rootArea[root] >= threshold) continue;

        // Largest adjacent root (ties -> smallest root id, deterministic).
        var target = -1;
        var targetArea = 0;
        for (var k = offsets[l]; k < offsets[l + 1]; k++) {
          final p = pixelsByLabel[k];
          final x = p % width;
          void consider(int q) {
            final o = find(labels[q]);
            if (o != root && rootArea[o] > targetArea) {
              target = o;
              targetArea = rootArea[o];
            }
          }

          if (x > 0) consider(p - 1);
          if (x < width - 1) consider(p + 1);
          if (p >= width) consider(p - width);
          if (p + width < labels.length) consider(p + width);
        }
        if (target == -1) continue; // one region covering the whole image

        parent[root] = target;
        rootArea[target] += rootArea[root];
        rootArea[root] = 0;
        changed = true;
      }
    }

    // Flatten the union-find into the grid.
    for (var i = 0; i < labels.length; i++) {
      labels[i] = find(labels[i]);
    }
  }
}
