class KvCacheQuotaStatus {
  final int kvFreeWriteLimit;
  final String kvResetAtUtc;
  final int kvSecondsToReset;
  final Map<String, dynamic> cachedKeys;
  final int maxWritesPerRequest;
  final int writesTotal;
  final int writesThisIsolate;

  const KvCacheQuotaStatus({
    required this.kvFreeWriteLimit,
    required this.kvResetAtUtc,
    required this.kvSecondsToReset,
    required this.cachedKeys,
    required this.maxWritesPerRequest,
    this.writesTotal       = 0,
    this.writesThisIsolate = 0,
  });

  int get cachedKeyCount =>
      cachedKeys.values.where((v) => (v as Map?)?['hit'] == true).length;
  int get totalKeys => cachedKeys.length;

  /// Fraction of daily write quota used (0.0 – 1.0).
  double get writeFraction => (writesTotal / kvFreeWriteLimit).clamp(0.0, 1.0);

  /// Remaining writes before the daily free limit is hit.
  int get remainingWrites => (kvFreeWriteLimit - writesTotal).clamp(0, kvFreeWriteLimit);

  String get resetLabel {
    if (kvSecondsToReset <= 0) return 'Resets soon';
    final h = kvSecondsToReset ~/ 3600;
    final m = (kvSecondsToReset % 3600) ~/ 60;
    if (h > 0) return 'Resets in ${h}h ${m}m';
    return 'Resets in ${m}m';
  }

  /// Fraction of the day elapsed (approximation using seconds to reset).
  double get dayFraction {
    if (kvSecondsToReset <= 0 || kvSecondsToReset >= 86400) return 0.0;
    return 1.0 - (kvSecondsToReset / 86400);
  }
}
