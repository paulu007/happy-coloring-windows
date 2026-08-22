import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../services/image_converter_service.dart';
import '../services/image_service.dart';
import '../screens/coloring_screen.dart';

/// Picks an image file (PNG/JPG/WebP/GIF/BMP), converts it into an uncolored
/// color-by-number template and opens it in the coloring screen.
///
/// Numbers are **never baked into the raster**; the canvas draws only
/// blank regions with thin strokes. The [colorNumber] per region is kept
/// in memory and used for tap-to-fill detection, long-press reveal, and
/// auto-paint. This keeps recordings/export clean while coloring stays
/// by-number.
Future<void> pickAndImportImage(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open file picker: $e')),
    );
    return;
  }
  if (result == null || result.files.isEmpty) return;

  final file = result.files.single;
  Uint8List? bytes = file.bytes;
  if (bytes == null && file.path != null) {
    bytes = await File(file.path!).readAsBytes();
  }
  if (bytes == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not read the selected file')),
    );
    return;
  }

  // Let user choose quality preset before conversion (defaults to balanced).
  // The preset only changes region/colour density; numbers always stay
  // hidden but detectable via region.colorNumber.
  final preset = await _pickPreset(context);
  if (preset == null) return; // cancelled
  final options = ConverterOptions.preset(preset);

  // Conversion runs in a background isolate; show a spinner meanwhile.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Converting image...'),
        ],
      ),
    ),
  );

  try {
    final image = await ImageService.instance.importImage(
      bytes: bytes,
      fileName: file.name,
      options: options,
    );
    navigator.pop(); // dialog

    if (context.mounted) {
      context.read<GalleryProvider>().refresh();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ColoringScreen(imageId: image.id),
        ),
      );
    }
  } catch (e) {
    navigator.pop(); // dialog
    messenger.showSnackBar(
      SnackBar(content: Text('Import failed: $e')),
    );
  }
}

Future<ConverterPreset?> _pickPreset(BuildContext context) async {
  return showDialog<ConverterPreset>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quality preset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Simple'),
            subtitle: const Text('Fewer colours, larger regions — easiest'),
            onTap: () => Navigator.pop(ctx, ConverterPreset.simple),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Balanced'),
            subtitle: const Text('Default — 16 colours, clean regions'),
            onTap: () => Navigator.pop(ctx, ConverterPreset.balanced),
          ),
          ListTile(
            leading: const Icon(Icons.details),
            title: const Text('Detailed'),
            subtitle: const Text('More colours & tiny regions — hard'),
            onTap: () => Navigator.pop(ctx, ConverterPreset.detailed),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  );
}
