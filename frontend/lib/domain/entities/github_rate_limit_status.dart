class GitHubRateLimitStatus {
  final int remaining;
  final int limit;
  final String resetAtIso;
  final bool isLow;

  const GitHubRateLimitStatus({
    required this.remaining,
    required this.limit,
    required this.resetAtIso,
    required this.isLow,
  });

  double get usedFraction {
    if (limit <= 0) return 0;
    final used = (limit - remaining).clamp(0, limit);
    return used / limit;
  }

  String get resetLabel {
    if (resetAtIso.isEmpty) return 'Unknown reset time';
    return 'Resets at $resetAtIso';
  }

}
