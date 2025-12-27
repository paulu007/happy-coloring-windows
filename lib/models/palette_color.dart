import 'dart:ui';

class PaletteColor {
  final int number;
  final Color color;
  final int totalRegions;
  int filledRegions;

  PaletteColor({
    required this.number,
    required this.color,
    required this.totalRegions,
    this.filledRegions = 0,
  });

  bool get isCompleted => filledRegions >= totalRegions;
  
  double get progress => totalRegions > 0 ? filledRegions / totalRegions : 0;

  PaletteColor copyWith({int? filledRegions}) {
    return PaletteColor(
      number: number,
      color: color,
      totalRegions: totalRegions,
      filledRegions: filledRegions ?? this.filledRegions,
    );
  }
}