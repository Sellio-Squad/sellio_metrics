class GitHubRateLimitModel {
  final int remaining;
  final int limit;
  final String resetAtIso;
  final bool isLow;

  const GitHubRateLimitModel({
    required this.remaining,
    required this.limit,
    required this.resetAtIso,
    required this.isLow,
  });

  factory GitHubRateLimitModel.fromJson(Map<String, dynamic> json) {
    return GitHubRateLimitModel(
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      resetAtIso: json['resetAt'] as String? ?? '',
      isLow: json['isLow'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remaining': remaining,
      'limit': limit,
      'resetAt': resetAtIso,
      'isLow': isLow,
    };
  }
}
