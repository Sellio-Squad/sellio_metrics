class RateLimitModel {
  final int remaining;
  final int limit;
  final String resetAt;
  final bool isLow;

  const RateLimitModel({
    required this.remaining,
    required this.limit,
    required this.resetAt,
    required this.isLow,
  });

  factory RateLimitModel.fromJson(Map<String, dynamic> json) => RateLimitModel(
        remaining: json['remaining'] as int? ?? 0,
        limit: json['limit'] as int? ?? 60,
        resetAt: json['resetAt'] as String? ?? '',
        isLow: json['isLow'] as bool? ?? false,
      );
}
