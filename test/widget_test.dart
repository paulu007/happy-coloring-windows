import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:happy_color_app/models/palette_color.dart';
import 'package:happy_color_app/widgets/color_palette.dart';

void main() {
  testWidgets('ColorPalette renders numbers and reports taps', (
    WidgetTester tester,
  ) async {
    final colors = [
      PaletteColor(number: 1, color: const Color(0xFF6C63FF), totalRegions: 3),
      PaletteColor(number: 2, color: const Color(0xFFFF6584), totalRegions: 5),
    ];
    PaletteColor? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorPalette(
            colors: colors,
            selectedColor: null,
            onColorSelected: (c) => picked = c,
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pump();

    expect(picked?.number, 2);
  });
}
