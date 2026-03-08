library;

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';

// ─── Model ──────────────────────────────────────────────────

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

  factory KvCacheQuotaStatus.fromJson(Map<String, dynamic> json) {
    return KvCacheQuotaStatus(
      kvFreeWriteLimit: (json['kvFreeWriteLimit'] as num?)?.toInt() ?? 1000,
      kvResetAtUtc: json['kvResetAtUtc'] as String? ?? '',
      kvSecondsToReset: (json['kvSecondsToReset'] as num?)?.toInt() ?? 0,
      cachedKeys: json['cachedKeys'] as Map<String, dynamic>? ?? {},
      maxWritesPerRequest:
          (json['maxWritesPerRequest'] as num?)?.toInt() ?? 3,
    );
  }

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

// ─── Widget ─────────────────────────────────────────────────

class KvCacheQuotaBanner extends StatefulWidget {
  const KvCacheQuotaBanner({super.key});

  @override
  State<KvCacheQuotaBanner> createState() => _KvCacheQuotaBannerState();
}

class _KvCacheQuotaBannerState extends State<KvCacheQuotaBanner> {
  KvCacheQuotaStatus? _status;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Refresh every 60 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetch());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/debug/cache-quota');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _status = KvCacheQuotaStatus.fromJson(data);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (_loading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Checking KV cache quota…',
            style: AppTypography.caption.copyWith(color: scheme.body),
          ),
        ],
      );
    }

    final status = _status;
    if (status == null) {
      return Text(
        'Unable to fetch KV cache quota.',
        style: AppTypography.caption.copyWith(color: scheme.hint),
      );
    }

    // Color the reset bar based on how close to midnight UTC we are
    final Color timeColor;
    if (status.kvSecondsToReset < 3600) {
      timeColor = scheme.green; // Nearly reset — good
    } else if (status.kvSecondsToReset < 10800) {
      timeColor = scheme.secondary; // A few hours left
    } else {
      timeColor = scheme.primary; // Many hours to reset
    }

    // Color cached-keys hits
    final Color keysColor;
    if (status.cachedKeyCount == status.totalKeys) {
      keysColor = scheme.green; // All cached — max efficiency
    } else if (status.cachedKeyCount > 0) {
      keysColor = scheme.secondary;
    } else {
      keysColor = scheme.red; // Nothing cached — next request will write
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.storage_outlined, size: 18, color: timeColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Cloudflare KV Cache',
              style: AppTypography.caption.copyWith(color: scheme.body),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _loading = true);
                _fetch();
              },
              child: Icon(Icons.refresh, size: 14, color: scheme.hint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Daily write limit info
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceHigh,
            borderRadius: AppRadius.smAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily write limit',
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                  Text(
                    '${status.kvFreeWriteLimit} writes/day (free tier)',
                    style: AppTypography.caption.copyWith(
                      color: scheme.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Max writes per request',
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.green.withOpacity(0.15),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      '≤ ${status.maxWritesPerRequest}',
                      style: AppTypography.caption.copyWith(
                        color: scheme.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Quota reset countdown bar
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: timeColor),
            const SizedBox(width: 4),
            Text(
              status.resetLabel,
              style: AppTypography.caption.copyWith(color: timeColor),
            ),
            const Spacer(),
            Text(
              'UTC midnight',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: status.dayFraction.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: scheme.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(timeColor),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Cache hit status
        Row(
          children: [
            Icon(Icons.bolt, size: 14, color: keysColor),
            const SizedBox(width: 4),
            Text(
              '${status.cachedKeyCount}/${status.totalKeys} result keys cached',
              style: AppTypography.caption.copyWith(color: keysColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Individual key indicators
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: status.cachedKeys.entries.map((e) {
            final hit = (e.value as Map?)?['hit'] == true;
            final label = e.key.split(':').last; // short label
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hit
                    ? scheme.green.withOpacity(0.12)
                    : scheme.red.withOpacity(0.10),
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: hit
                      ? scheme.green.withOpacity(0.3)
                      : scheme.red.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hit ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    size: 10,
                    color: hit ? scheme.green : scheme.red,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: hit ? scheme.green : scheme.hint,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
