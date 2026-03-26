/// GeminiUsageEntity — maps to GET /api/review/usage response.
class GeminiUsageEntity {
  final String model;
  final int requestsToday;
  final int errorsToday;
  final DateTime? lastRequestAt;
  final DateTime? lastErrorAt;
  final int? lastErrorCode;
  final String? lastErrorMessage;
  final int? retryAfterSeconds;
  final int dailyRequestLimit;
  final int minuteRequestLimit;

  const GeminiUsageEntity({
    required this.model,
    required this.requestsToday,
    required this.errorsToday,
    this.lastRequestAt,
    this.lastErrorAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.retryAfterSeconds,
    required this.dailyRequestLimit,
    required this.minuteRequestLimit,
  });

  /// Fraction of daily limit consumed (0.0 – 1.0)
  double get dailyUsedFraction =>
      dailyRequestLimit > 0 ? (requestsToday / dailyRequestLimit).clamp(0.0, 1.0) : 0.0;

  bool get isRateLimited => retryAfterSeconds != null && retryAfterSeconds! > 0;

  bool get hasErrors => errorsToday > 0;

  factory GeminiUsageEntity.fromJson(Map<String, dynamic> json) {
    return GeminiUsageEntity(
      model: json['model'] as String? ?? 'unknown',
      requestsToday: json['requestsToday'] as int? ?? 0,
      errorsToday: json['errorsToday'] as int? ?? 0,
      lastRequestAt: json['lastRequestAt'] != null
          ? DateTime.tryParse(json['lastRequestAt'] as String)
          : null,
      lastErrorAt: json['lastErrorAt'] != null
          ? DateTime.tryParse(json['lastErrorAt'] as String)
          : null,
      lastErrorCode: json['lastErrorCode'] as int?,
      lastErrorMessage: json['lastErrorMessage'] as String?,
      retryAfterSeconds: json['retryAfterSeconds'] as int?,
      dailyRequestLimit: json['dailyRequestLimit'] as int? ?? 1500,
      minuteRequestLimit: json['minuteRequestLimit'] as int? ?? 30,
    );
  }
}
