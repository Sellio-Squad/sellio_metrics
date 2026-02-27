/// Sellio Metrics — Observability Domain Entities (v2 — Advanced)
///
/// Pure domain models — immutable data classes, no framework deps.
/// Matches the backend's advanced ObservabilityStats structure.
library;

// ─── Single API Call ────────────────────────────────────────

class ApiCallEntity {
  final int id;
  final String source;
  final String method;
  final String path;
  final int statusCode;
  final double durationMs;
  final String timestamp;
  final String? error;

  const ApiCallEntity({
    required this.id,
    required this.source,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.timestamp,
    this.error,
  });

  bool get isError => statusCode >= 400;
  bool get isSuccess => statusCode >= 200 && statusCode < 400;

  factory ApiCallEntity.fromJson(Map<String, dynamic> json) => ApiCallEntity(
        id: json['id'] as int? ?? 0,
        source: json['source'] as String? ?? 'unknown',
        method: json['method'] as String? ?? 'GET',
        path: json['path'] as String? ?? '',
        statusCode: json['statusCode'] as int? ?? 0,
        durationMs: (json['durationMs'] as num?)?.toDouble() ?? 0.0,
        timestamp: json['timestamp'] as String? ?? '',
        error: json['error'] as String?,
      );
}

// ─── Latency Percentiles ────────────────────────────────────

class LatencyPercentilesEntity {
  final double p50;
  final double p75;
  final double p90;
  final double p95;
  final double p99;
  final double min;
  final double max;
  final double avg;

  const LatencyPercentilesEntity({
    required this.p50,
    required this.p75,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.min,
    required this.max,
    required this.avg,
  });

  static const zero = LatencyPercentilesEntity(
    p50: 0, p75: 0, p90: 0, p95: 0, p99: 0, min: 0, max: 0, avg: 0,
  );

  factory LatencyPercentilesEntity.fromJson(Map<String, dynamic> json) =>
      LatencyPercentilesEntity(
        p50: (json['p50'] as num?)?.toDouble() ?? 0.0,
        p75: (json['p75'] as num?)?.toDouble() ?? 0.0,
        p90: (json['p90'] as num?)?.toDouble() ?? 0.0,
        p95: (json['p95'] as num?)?.toDouble() ?? 0.0,
        p99: (json['p99'] as num?)?.toDouble() ?? 0.0,
        min: (json['min'] as num?)?.toDouble() ?? 0.0,
        max: (json['max'] as num?)?.toDouble() ?? 0.0,
        avg: (json['avg'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─── Latency by Source ──────────────────────────────────────

class LatencyBySourceEntity {
  final String source;
  final LatencyPercentilesEntity percentiles;
  final int callCount;

  const LatencyBySourceEntity({
    required this.source,
    required this.percentiles,
    required this.callCount,
  });

  factory LatencyBySourceEntity.fromJson(Map<String, dynamic> json) =>
      LatencyBySourceEntity(
        source: json['source'] as String? ?? 'unknown',
        percentiles: LatencyPercentilesEntity.fromJson(
            json['percentiles'] as Map<String, dynamic>? ?? {}),
        callCount: json['callCount'] as int? ?? 0,
      );
}

// ─── Rate Limit ─────────────────────────────────────────────

class RateLimitEntity {
  final String source;
  final int limit;
  final int remaining;
  final int used;
  final String resetAt;
  final double percentUsed;

  const RateLimitEntity({
    required this.source,
    required this.limit,
    required this.remaining,
    required this.used,
    required this.resetAt,
    required this.percentUsed,
  });

  double get percentRemaining => 1.0 - percentUsed;

  factory RateLimitEntity.fromJson(Map<String, dynamic> json) => RateLimitEntity(
        source: json['source'] as String? ?? 'unknown',
        limit: json['limit'] as int? ?? 0,
        remaining: json['remaining'] as int? ?? 0,
        used: json['used'] as int? ?? 0,
        resetAt: json['resetAt'] as String? ?? '',
        percentUsed: (json['percentUsed'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─── Abuse / Spike Detection ────────────────────────────────

class HotEndpointEntity {
  final String method;
  final String path;
  final int callsPerMinute;

  const HotEndpointEntity({
    required this.method,
    required this.path,
    required this.callsPerMinute,
  });

  factory HotEndpointEntity.fromJson(Map<String, dynamic> json) =>
      HotEndpointEntity(
        method: json['method'] as String? ?? 'GET',
        path: json['path'] as String? ?? '',
        callsPerMinute: json['callsPerMinute'] as int? ?? 0,
      );
}

class AbuseMetricsEntity {
  final int callsPerMinute;
  final int prevCallsPerMinute;
  final int trend;
  final bool isSpiking;
  final int trailingAvg5Min;
  final int peakCallsPerMinute;
  final List<HotEndpointEntity> hotEndpoints;

  const AbuseMetricsEntity({
    required this.callsPerMinute,
    required this.prevCallsPerMinute,
    required this.trend,
    required this.isSpiking,
    required this.trailingAvg5Min,
    required this.peakCallsPerMinute,
    required this.hotEndpoints,
  });

  static const zero = AbuseMetricsEntity(
    callsPerMinute: 0,
    prevCallsPerMinute: 0,
    trend: 0,
    isSpiking: false,
    trailingAvg5Min: 0,
    peakCallsPerMinute: 0,
    hotEndpoints: [],
  );

  String get trendLabel {
    if (trend > 0) return '+$trend%';
    if (trend < 0) return '$trend%';
    return '0%';
  }

  factory AbuseMetricsEntity.fromJson(Map<String, dynamic> json) =>
      AbuseMetricsEntity(
        callsPerMinute: json['callsPerMinute'] as int? ?? 0,
        prevCallsPerMinute: json['prevCallsPerMinute'] as int? ?? 0,
        trend: json['trend'] as int? ?? 0,
        isSpiking: json['isSpiking'] as bool? ?? false,
        trailingAvg5Min: json['trailingAvg5Min'] as int? ?? 0,
        peakCallsPerMinute: json['peakCallsPerMinute'] as int? ?? 0,
        hotEndpoints: (json['hotEndpoints'] as List<dynamic>?)
                ?.map((e) => HotEndpointEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ─── Service Dependency Graph ───────────────────────────────

class DependencyNodeEntity {
  final String id;
  final String label;
  final String type;

  const DependencyNodeEntity({
    required this.id,
    required this.label,
    required this.type,
  });

  factory DependencyNodeEntity.fromJson(Map<String, dynamic> json) =>
      DependencyNodeEntity(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'service',
      );
}

class DependencyEdgeEntity {
  final String from;
  final String to;
  final int callCount;
  final double avgDurationMs;
  final int errorCount;
  final String lastCallAt;

  const DependencyEdgeEntity({
    required this.from,
    required this.to,
    required this.callCount,
    required this.avgDurationMs,
    required this.errorCount,
    required this.lastCallAt,
  });

  bool get hasErrors => errorCount > 0;

  factory DependencyEdgeEntity.fromJson(Map<String, dynamic> json) =>
      DependencyEdgeEntity(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        callCount: json['callCount'] as int? ?? 0,
        avgDurationMs: (json['avgDurationMs'] as num?)?.toDouble() ?? 0.0,
        errorCount: json['errorCount'] as int? ?? 0,
        lastCallAt: json['lastCallAt'] as String? ?? '',
      );
}

class DependencyGraphEntity {
  final List<DependencyNodeEntity> nodes;
  final List<DependencyEdgeEntity> edges;

  const DependencyGraphEntity({required this.nodes, required this.edges});

  static const empty = DependencyGraphEntity(nodes: [], edges: []);

  factory DependencyGraphEntity.fromJson(Map<String, dynamic> json) =>
      DependencyGraphEntity(
        nodes: (json['nodes'] as List<dynamic>?)
                ?.map((e) => DependencyNodeEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        edges: (json['edges'] as List<dynamic>?)
                ?.map((e) => DependencyEdgeEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ─── Source Breakdown ───────────────────────────────────────

class SourceBreakdownEntity {
  final String source;
  final int count;
  final double avgDurationMs;
  final int errorCount;
  final double errorRate;

  const SourceBreakdownEntity({
    required this.source,
    required this.count,
    required this.avgDurationMs,
    required this.errorCount,
    required this.errorRate,
  });

  factory SourceBreakdownEntity.fromJson(Map<String, dynamic> json) =>
      SourceBreakdownEntity(
        source: json['source'] as String? ?? 'unknown',
        count: json['count'] as int? ?? 0,
        avgDurationMs: (json['avgDurationMs'] as num?)?.toDouble() ?? 0.0,
        errorCount: json['errorCount'] as int? ?? 0,
        errorRate: (json['errorRate'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─── Slow Endpoint ──────────────────────────────────────────

class SlowEndpointEntity {
  final String method;
  final String path;
  final double avgDurationMs;
  final double maxDurationMs;
  final double p95DurationMs;
  final int callCount;

  const SlowEndpointEntity({
    required this.method,
    required this.path,
    required this.avgDurationMs,
    required this.maxDurationMs,
    required this.p95DurationMs,
    required this.callCount,
  });

  factory SlowEndpointEntity.fromJson(Map<String, dynamic> json) =>
      SlowEndpointEntity(
        method: json['method'] as String? ?? 'GET',
        path: json['path'] as String? ?? '',
        avgDurationMs: (json['avgDurationMs'] as num?)?.toDouble() ?? 0.0,
        maxDurationMs: (json['maxDurationMs'] as num?)?.toDouble() ?? 0.0,
        p95DurationMs: (json['p95DurationMs'] as num?)?.toDouble() ?? 0.0,
        callCount: json['callCount'] as int? ?? 0,
      );
}

// ─── Recent Error ───────────────────────────────────────────

class RecentErrorEntity {
  final int id;
  final String source;
  final String method;
  final String path;
  final int statusCode;
  final String error;
  final String timestamp;

  const RecentErrorEntity({
    required this.id,
    required this.source,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.error,
    required this.timestamp,
  });

  factory RecentErrorEntity.fromJson(Map<String, dynamic> json) =>
      RecentErrorEntity(
        id: json['id'] as int? ?? 0,
        source: json['source'] as String? ?? 'unknown',
        method: json['method'] as String? ?? 'GET',
        path: json['path'] as String? ?? '',
        statusCode: json['statusCode'] as int? ?? 0,
        error: json['error'] as String? ?? 'Unknown error',
        timestamp: json['timestamp'] as String? ?? '',
      );
}

// ─── Aggregated Stats (v2) ──────────────────────────────────

class ObservabilityStatsEntity {
  final int totalCalls;
  final double errorRate;
  final int uptimeMs;
  final String generatedAt;
  final LatencyPercentilesEntity latency;
  final List<LatencyBySourceEntity> latencyBySource;
  final List<RateLimitEntity> rateLimits;
  final AbuseMetricsEntity abuse;
  final List<SourceBreakdownEntity> callsBySource;
  final List<SlowEndpointEntity> slowestEndpoints;
  final List<RecentErrorEntity> recentErrors;
  final DependencyGraphEntity dependencyGraph;

  const ObservabilityStatsEntity({
    required this.totalCalls,
    required this.errorRate,
    required this.uptimeMs,
    required this.generatedAt,
    required this.latency,
    required this.latencyBySource,
    required this.rateLimits,
    required this.abuse,
    required this.callsBySource,
    required this.slowestEndpoints,
    required this.recentErrors,
    required this.dependencyGraph,
  });

  String get formattedUptime {
    final seconds = uptimeMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    if (hours > 0) return '${hours}h ${minutes % 60}m';
    if (minutes > 0) return '${minutes}m ${seconds % 60}s';
    return '${seconds}s';
  }

  double get errorPercent => errorRate * 100;

  bool get isEmpty => totalCalls == 0;

  factory ObservabilityStatsEntity.fromJson(Map<String, dynamic> json) =>
      ObservabilityStatsEntity(
        totalCalls: json['totalCalls'] as int? ?? 0,
        errorRate: (json['errorRate'] as num?)?.toDouble() ?? 0.0,
        uptimeMs: json['uptimeMs'] as int? ?? 0,
        generatedAt: json['generatedAt'] as String? ?? '',
        latency: LatencyPercentilesEntity.fromJson(
            json['latency'] as Map<String, dynamic>? ?? {}),
        latencyBySource: (json['latencyBySource'] as List<dynamic>?)
                ?.map((e) => LatencyBySourceEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        rateLimits: (json['rateLimits'] as List<dynamic>?)
                ?.map((e) => RateLimitEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        abuse: AbuseMetricsEntity.fromJson(
            json['abuse'] as Map<String, dynamic>? ?? {}),
        callsBySource: (json['callsBySource'] as List<dynamic>?)
                ?.map((e) => SourceBreakdownEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        slowestEndpoints: (json['slowestEndpoints'] as List<dynamic>?)
                ?.map((e) => SlowEndpointEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        recentErrors: (json['recentErrors'] as List<dynamic>?)
                ?.map((e) => RecentErrorEntity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        dependencyGraph: DependencyGraphEntity.fromJson(
            json['dependencyGraph'] as Map<String, dynamic>? ?? {}),
      );

  static const empty = ObservabilityStatsEntity(
    totalCalls: 0,
    errorRate: 0,
    uptimeMs: 0,
    generatedAt: '',
    latency: LatencyPercentilesEntity.zero,
    latencyBySource: [],
    rateLimits: [],
    abuse: AbuseMetricsEntity.zero,
    callsBySource: [],
    slowestEndpoints: [],
    recentErrors: [],
    dependencyGraph: DependencyGraphEntity.empty,
  );
}
