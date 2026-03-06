library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';

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

  factory GitHubRateLimitStatus.fromJson(Map<String, dynamic> json) {
    return GitHubRateLimitStatus(
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      resetAtIso: json['resetAt'] as String? ?? '',
      isLow: json['isLow'] as bool? ?? false,
    );
  }
}

class GitHubRateLimitBanner extends StatefulWidget {
  const GitHubRateLimitBanner({super.key});

  @override
  State<GitHubRateLimitBanner> createState() => _GitHubRateLimitBannerState();
}

class _GitHubRateLimitBannerState extends State<GitHubRateLimitBanner> {
  late Future<GitHubRateLimitStatus?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchStatus();
  }

  Future<GitHubRateLimitStatus?> _fetchStatus() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/health');

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;

      final rateJson = body['githubRateLimit'];
      if (rateJson is Map<String, dynamic>) {
        return GitHubRateLimitStatus.fromJson(rateJson);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return FutureBuilder<GitHubRateLimitStatus?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Checking GitHub API rate limit…',
                style: AppTypography.body.copyWith(color: scheme.body),
              ),
            ],
          );
        }

        final status = snapshot.data;
        if (status == null) {
          return Text(
            'Unable to fetch GitHub API rate limit.',
            style: AppTypography.caption.copyWith(color: scheme.hint),
          );
        }

        final usedFraction = status.usedFraction;
        final remaining = status.remaining;
        final limit = status.limit;

        final Color barColor;
        if (remaining <= (limit * 0.1)) {
          barColor = scheme.red;
        } else if (remaining <= (limit * 0.3)) {
          barColor = scheme.secondary;
        } else {
          barColor = scheme.green;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_outlined, size: 18, color: barColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'GitHub API rate limit',
                  style: AppTypography.caption.copyWith(color: scheme.body),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: LinearProgressIndicator(
                value: usedFraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceHigh,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$remaining remaining of $limit',
                  style: AppTypography.caption.copyWith(color: scheme.body),
                ),
                Text(
                  status.resetLabel,
                  style: AppTypography.caption.copyWith(color: scheme.hint),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
