class KvCacheQuotaModel {
  final int kvFreeWriteLimit;
  final String kvResetAtUtc;
  final int kvSecondsToReset;
  final Map<String, dynamic> cachedKeys;
  final int maxWritesPerRequest;

  const KvCacheQuotaModel({
    required this.kvFreeWriteLimit,
    required this.kvResetAtUtc,
    required this.kvSecondsToReset,
    required this.cachedKeys,
    required this.maxWritesPerRequest,
  });

  factory KvCacheQuotaModel.fromJson(Map<String, dynamic> json) {
    return KvCacheQuotaModel(
      kvFreeWriteLimit: (json['kvFreeWriteLimit'] as num?)?.toInt() ?? 1000,
      kvResetAtUtc: json['kvResetAtUtc'] as String? ?? '',
      kvSecondsToReset: (json['kvSecondsToReset'] as num?)?.toInt() ?? 0,
      cachedKeys: json['cachedKeys'] as Map<String, dynamic>? ?? {},
      maxWritesPerRequest: (json['maxWritesPerRequest'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kvFreeWriteLimit': kvFreeWriteLimit,
      'kvResetAtUtc': kvResetAtUtc,
      'kvSecondsToReset': kvSecondsToReset,
      'cachedKeys': cachedKeys,
      'maxWritesPerRequest': maxWritesPerRequest,
    };
  }
}
