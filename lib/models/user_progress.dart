class UserProgress {
  final String imageId;
  final List<int> filledRegionIds;
  final DateTime lastModified;
  final bool isCompleted;

  UserProgress({
    required this.imageId,
    required this.filledRegionIds,
    required this.lastModified,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      'filledRegionIds': filledRegionIds.join(','),
      'lastModified': lastModified.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory UserProgress.fromMap(Map<String, dynamic> map) {
    final filledIds = (map['filledRegionIds'] as String)
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s))
        .toList();

    return UserProgress(
      imageId: map['imageId'],
      filledRegionIds: filledIds,
      lastModified: DateTime.fromMillisecondsSinceEpoch(map['lastModified']),
      isCompleted: map['isCompleted'] == 1,
    );
  }
}