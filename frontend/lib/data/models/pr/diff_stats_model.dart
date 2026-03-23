/// Diff statistics for a PR.
class DiffStats {
  final int additions;
  final int deletions;
  final int changedFiles;

  const DiffStats({
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  int get totalChanges => additions + deletions;

  factory DiffStats.fromJson(Map<String, dynamic> json) => DiffStats(
    additions: json['additions'] as int? ?? 0,
    deletions: json['deletions'] as int? ?? 0,
    changedFiles: json['changed_files'] as int? ?? 0,
  );
}
