class DiffStatsEntity {
  final int additions;
  final int deletions;
  final int changedFiles;

  const DiffStatsEntity({
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  int get totalChanges => additions + deletions;
}