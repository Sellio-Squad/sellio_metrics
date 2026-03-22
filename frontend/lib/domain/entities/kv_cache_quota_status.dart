class KvCacheQuotaStatus {
  final int kvFreeWriteLimit;
  final String kvResetAtUtc;
  final int kvSecondsToReset;
  final Map<String, dynamic> cachedKeys;
  final int maxWritesPerRequest;

  const KvCacheQuotaStatus({
    required this.kvFreeWriteLimit,
    required this.kvResetAtUtc,
    required this.kvSecondsToReset,
    required this.cachedKeys,
    required this.maxWritesPerRequest,
  });

  int get cachedKeyCount =>
      cachedKeys.values.where((v) => (v as Map?)?['hit'] == true).length;
  int get totalKeys => cachedKeys.length;

  String get resetLabel {
    if (kvSecondsToReset <= 0) return 'Resets soon';
    final h = kvSecondsToReset ~/ 3600;
    final m = (kvSecondsToReset % 3600) ~/ 60;
    if (h > 0) return 'Resets in ${h}h ${m}m';
    return 'Resets in ${m}m';
  }

  /// Fraction of the day elapsed (approximation using seconds to reset).
  /// 86400 seconds = 24 hours
  double get dayFraction {
    if (kvSecondsToReset <= 0 || kvSecondsToReset >= 86400) return 0.0;
    return 1.0 - (kvSecondsToReset / 86400);
  }
}
