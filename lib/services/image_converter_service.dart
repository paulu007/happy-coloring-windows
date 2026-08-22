import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/coloring_image.dart';
import '../models/color_region.dart';
import '../models/palette_color.dart';

/// Difficulty / quality presets for the converter.
enum ConverterPreset { simple, balanced, detailed }

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

  /// Lloyd (k-means) iterations used to refine the median-cut palette so the
  /// generated colors match the source image more closely.
  final int refineIterations;

  /// Use perceptual CIELAB (Delta E) distance for quantization/mapping instead
  /// of weighted RGB. Better matches human perception; slightly more CPU.
  final bool useLabDistance;

  /// Preserve edges during smoothing — border pixels keep their original
  /// palette index, so smoothing cannot bleed across region boundaries.
  final bool edgeAwareSmoothing;

  /// Slight contrast boost applied before quantization (0.0 = off, ~0.08
  /// recommended). Makes dull photos separate into more distinct regions.
  final double contrastBoost;

  const ConverterOptions({
    this.maxColors = 16,
    this.maxDimension = 480,
    this.minRegionArea = 16,
    this.smoothingPasses = 2,
    this.refineIterations = 4,
    this.useLabDistance = true,
    this.edgeAwareSmoothing = true,
    this.contrastBoost = 0.06,
  });

  factory ConverterOptions.preset(ConverterPreset preset) {
    switch (preset) {
      case ConverterPreset.simple:
        return const ConverterOptions(
            maxColors: 10,
            maxDimension: 400,
            minRegionArea: 28,
            smoothingPasses: 3,
            refineIterations: 2);
      case ConverterPreset.detailed:
        return const ConverterOptions(
            maxColors: 24,
            maxDimension: 640,
            minRegionArea: 10,
            smoothingPasses: 1,
            refineIterations: 6);
      case ConverterPreset.balanced:
        return const ConverterOptions();
    }
  }

  ConverterOptions copyWith({
    int? maxColors,
    int? maxDimension,
    int? minRegionArea,
    int? smoothingPasses,
    int? refineIterations,
    bool? useLabDistance,
    bool? edgeAwareSmoothing,
    double? contrastBoost,
  }) =>
      ConverterOptions(
        maxColors: maxColors ?? this.maxColors,
        maxDimension: maxDimension ?? this.maxDimension,
        minRegionArea: minRegionArea ?? this.minRegionArea,
        smoothingPasses: smoothingPasses ?? this.smoothingPasses,
        refineIterations: refineIterations ?? this.refineIterations,
        useLabDistance: useLabDistance ?? this.useLabDistance,
        edgeAwareSmoothing: edgeAwareSmoothing ?? this.edgeAwareSmoothing,
        contrastBoost: contrastBoost ?? this.contrastBoost,
      );
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

      // Merge vertically contiguous runs with identical x-extent into a
      // single rect. Runs arrive in scan order, so stacked runs are adjacent
      // in the list. This typically cuts the rect count (and therefore both
      // painting and hit-testing cost) by 3-5x.
      var started = false;
      var runY0 = 0.0, runY1 = 0.0, runX0 = 0.0, runX1 = 0.0;
      for (var j = 0; j < r.runs.length; j += 3) {
        final y = r.runs[j].toDouble();
        final x0 = r.runs[j + 1].toDouble();
        final x1 = r.runs[j + 2] + 1.0;

        if (started && x0 == runX0 && x1 == runX1 && y == runY1 + 1.0) {
          runY1 = y; // extend current rect downwards
          continue;
        }
        if (started) {
          path.addRect(Rect.fromLTRB(runX0, runY0, runX1, runY1 + 1.0));
        }
        started = true;
        runY0 = y;
        runY1 = y;
        runX0 = x0;
        runX1 = x1;
      }
      if (started) {
        path.addRect(Rect.fromLTRB(runX0, runY0, runX1, runY1 + 1.0));
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

  // 2. Flatten to opaque 0xRRGGBB pixels (composite over white) + optional
  //    contrast expansion around the per-channel mean.
  final pixels = Uint32List(pixelCount);
  var i = 0;
  for (final p in working) {
    final a = (p.a * 255).round().clamp(0, 255);
    final r = ((p.r * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    final g = ((p.g * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    final b = ((p.b * 255).round().clamp(0, 255) * a + 255 * (255 - a)) ~/ 255;
    pixels[i++] = (r << 16) | (g << 8) | b;
  }
  if (options.contrastBoost > 0.001) {
    _applyContrastBoost(pixels, options.contrastBoost);
  }

  // 3. Quantize to a small palette and map every pixel to its nearest color.
  final maxColors = options.maxColors.clamp(2, 48).toInt();
  var palette = MedianCutQuantizer.quantize(pixels, maxColors);
  var indices = NearestColorMapper.map(pixels, palette,
      useLab: options.useLabDistance);

  // 3b. Refine palette centers with a few deterministic Lloyd (k-means)
  //     iterations so the final colors better match the source image.
  if (options.refineIterations > 0 && palette.length > 1) {
    final refined = PaletteRefiner.refine(
      pixels,
      palette,
      indices,
      iterations: options.refineIterations,
      useLab: options.useLabDistance,
    );
    palette = refined;
    indices = NearestColorMapper.map(pixels, palette,
        useLab: options.useLabDistance);
  }

  // 4. Remove noise with majority filtering before segmentation.
  for (var pass = 0; pass < options.smoothingPasses; pass++) {
    indices = MajoritySmoother.smooth(indices, palette.length, width, height,
        edgeAware: options.edgeAwareSmoothing);
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

// Contrast expansion helper: gently push each channel away from its mean
// so near-identical tones separate into distinct regions deterministically.
void _applyContrastBoost(Uint32List pixels, double boost) {
  var sumR = 0, sumG = 0, sumB = 0;
  for (final p in pixels) {
    sumR += (p >> 16) & 0xFF;
    sumG += (p >> 8) & 0xFF;
    sumB += p & 0xFF;
  }
  final n = pixels.length;
  if (n == 0) return;
  final meanR = sumR / n, meanG = sumG / n, meanB = sumB / n;
  for (var i = 0; i < n; i++) {
    final p = pixels[i];
    int r = (p >> 16) & 0xFF;
    int g = (p >> 8) & 0xFF;
    int b = p & 0xFF;
    r = (meanR + (r - meanR) * (1 + boost)).round().clamp(0, 255).toInt();
    g = (meanG + (g - meanG) * (1 + boost)).round().clamp(0, 255).toInt();
    b = (meanB + (b - meanB) * (1 + boost)).round().clamp(0, 255).toInt();
    pixels[i] = (r << 16) | (g << 8) | b;
  }
}

// ---------------------------------------------------------------------------
// K-means palette refinement
// ---------------------------------------------------------------------------

/// Deterministic Lloyd-iteration refiner: moves each palette color to the
/// mean of the pixels currently assigned to it. Empty clusters keep their
/// previous color, which keeps the result reproducible.
class PaletteRefiner {
  static List<int> refine(
    Uint32List pixels,
    List<int> palette,
    Uint8List indices, {
    required int iterations,
    bool useLab = true,
  }) {
    final n = palette.length;
    final sums = List<Int64List>.generate(n, (_) => Int64List(3));
    final counts = Int64List(n);
    final current = List<int>.of(palette);

    for (var iter = 0; iter < iterations; iter++) {
      for (var c = 0; c < n; c++) {
        sums[c][0] = 0;
        sums[c][1] = 0;
        sums[c][2] = 0;
        counts[c] = 0;
      }
      for (var i = 0; i < pixels.length; i++) {
        final p = pixels[i];
        final bin = indices[i];
        sums[bin][0] += (p >> 16) & 0xFF;
        sums[bin][1] += (p >> 8) & 0xFF;
        sums[bin][2] += p & 0xFF;
        counts[bin]++;
      }
      for (var c = 0; c < n; c++) {
        if (counts[c] == 0) continue;
        current[c] = 0xFF000000 |
            ((sums[c][0] ~/ counts[c]) << 16) |
            ((sums[c][1] ~/ counts[c]) << 8) |
            (sums[c][2] ~/ counts[c]);
      }
      // Re-assign for the next iteration (and for the caller's final map).
      for (var i = 0; i < pixels.length; i++) {
        indices[i] = NearestColorMapper.nearest(pixels[i], current, useLab: useLab);
      }
    }
    return current;
  }
}

// ---------------------------------------------------------------------------
// Nearest-color mapping
// ---------------------------------------------------------------------------

class NearestColorMapper {
  /// Maps every pixel to the index of its nearest palette color.
  /// When [useLab] is true uses approximate CIELAB Delta E (perceptual);
  /// otherwise falls back to weighted RGB (2R,4G,3B).
  static Uint8List map(Uint32List pixels, List<int> palette, {bool useLab = true}) {
    if (!useLab) {
      final out = Uint8List(pixels.length);
      for (var i = 0; i < pixels.length; i++) out[i] = nearest(pixels[i], palette, useLab: false);
      return out;
    }
    // Precompute palette LAB once.
    final labPalette = List<_Lab>.generate(palette.length, (j) {
      final c = palette[j];
      return _Lab.fromRgb((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
    });
    final out = Uint8List(pixels.length);
    for (var i = 0; i < pixels.length; i++) {
      final p = pixels[i];
      final lab = _Lab.fromRgb((p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF);
      var best = 0;
      var bestDist = double.infinity;
      for (var j = 0; j < labPalette.length; j++) {
        final d = lab.deltaE(labPalette[j]);
        if (d < bestDist) { bestDist = d; best = j; }
      }
      out[i] = best;
    }
    return out;
  }

  static int nearest(int pixel, List<int> palette, {bool useLab = true}) {
    if (palette.length == 1) return 0;
    if (!useLab) {
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
        if (dist < bestDist) { bestDist = dist; best = j; }
      }
      return best;
    }
    final r = (pixel >> 16) & 0xFF;
    final g = (pixel >> 8) & 0xFF;
    final b = pixel & 0xFF;
    final lab = _Lab.fromRgb(r, g, b);
    var best = 0;
    var bestDist = double.infinity;
    for (var j = 0; j < palette.length; j++) {
      final c = palette[j];
      final plab = _Lab.fromRgb((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
      final d = lab.deltaE(plab);
      if (d < bestDist) { bestDist = d; best = j; }
    }
    return best;
  }
}

// Minimal sRGB → CIELAB helper (D65, approx. Delta E 1976).
class _Lab {
  final double l, a, b;
  const _Lab(this.l, this.a, this.b);
  factory _Lab.fromRgb(int r, int g, int b) {
    double rl = r / 255.0, gl = g / 255.0, bl = b / 255.0;
    rl = rl <= 0.04045 ? rl / 12.92 : math.pow((rl + 0.055) / 1.055, 2.4).toDouble();
    gl = gl <= 0.04045 ? gl / 12.92 : math.pow((gl + 0.055) / 1.055, 2.4).toDouble();
    bl = bl <= 0.04045 ? bl / 12.92 : math.pow((bl + 0.055) / 1.055, 2.4).toDouble();
    final x = rl * 0.4124 + gl * 0.3576 + bl * 0.1805;
    final y = rl * 0.2126 + gl * 0.7152 + bl * 0.0722;
    final z = rl * 0.0193 + gl * 0.1192 + bl * 0.9505;
    const xn = 0.95047, yn = 1.0, zn = 1.08883;
    double fx(double t) => t > 0.008856 ? math.pow(t, 1/3).toDouble() : (7.787 * t + 16/116);
    final fx_ = fx(x / xn), fy = fx(y / yn), fz = fx(z / zn);
    return _Lab(116 * fy - 16, 500 * (fx_ - fy), 200 * (fy - fz));
  }
  double deltaE(_Lab o) {
    final dl = l - o.l, da = a - o.a, db = b - o.b;
    return dl*dl + da*da + db*db;
  }
}

// ---------------------------------------------------------------------------
// Majority smoothing
// ---------------------------------------------------------------------------

class MajoritySmoother {
  /// One 3x3 mode filter pass: each pixel becomes the most common palette
  /// index in its neighborhood (ties keep the current value, so the pass is
  /// deterministic). When [edgeAware] is true, border pixels (where the 3x3
  /// window spans more than one color) are left untouched, preserving detail
  /// and crisp region edges — this is the key to keeping small features while
  /// removing isolated speckles.
  static Uint8List smooth(
      Uint8List indices, int paletteLength, int width, int height,
      {bool edgeAware = true}) {
    final counts = List<int>.filled(paletteLength, 0);
    final out = Uint8List(indices.length);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        final cur = indices[i];
        // Edge-aware: if neighborhood is heterogeneous, keep original to preserve edge.
        if (edgeAware) {
          var distinct = 0;
          var seenMask = 0;
          // paletteLength <=48 so bitmask fits in 64 bits; for larger palette use set.
          if (paletteLength <= 64) {
            for (var dy = -1; dy <= 1; dy++) {
              final ny = y + dy;
              if (ny < 0 || ny >= height) continue;
              for (var dx = -1; dx <= 1; dx++) {
                final nx = x + dx;
                if (nx < 0 || nx >= width) continue;
                final v = indices[ny * width + nx];
                final bit = 1 << (v % 64);
                if ((seenMask & bit) == 0) { // approximate for >64 handled below fallback
                  seenMask |= bit;
                  distinct++;
                }
              }
            }
            // If more than 2 distinct colors in 3x3 this is likely an edge/boundary.
            if (distinct > 2) {
              out[i] = cur;
              continue;
            }
          }
        }
        for (var c = 0; c < paletteLength; c++) counts[c] = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            counts[indices[ny * width + nx]]++;
          }
        }
        var best = cur;
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
