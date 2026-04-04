import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/issues/issues_data_source.dart';

@Injectable(as: IssuesDataSource, env: [Environment.dev])
class FakeIssuesDataSource implements IssuesDataSource {
  static final _now = DateTime.now();

  static final List<Map<String, dynamic>> _issues = [
    // ── Overdue (red) ─────────────────────────────────────────
    {
      'number': 42,
      'title': 'Fix checkout flow crash on iOS 17',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_mobile/issues/42',
      'html_url': 'https://github.com/Sellio-Squad/sellio_mobile/issues/42',
      'repo_name': 'sellio_mobile',
      'author': {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      'assignees': [
        {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      ],
      'labels': [
        {'name': 'bug', 'color': 'ee0701'},
        {'name': 'critical', 'color': 'b60205'},
        {'name': 'iOS', 'color': '0075ca'},
      ],
      'created_at': _now.subtract(const Duration(days: 14)).toIso8601String(),
      'milestone': {
        'title': 'Sprint 12',
        'due_on': _now.subtract(const Duration(days: 3)).toIso8601String(),
      },
      'priority': 'critical',
      'body': 'The checkout flow crashes when user taps confirm on iOS 17.4+. Reproducible 100% of the time. Blocker for release.',
    },
    {
      'number': 38,
      'title': 'Payment gateway timeout issue in production',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_backend/issues/38',
      'html_url': 'https://github.com/Sellio-Squad/sellio_backend/issues/38',
      'repo_name': 'sellio_backend',
      'author': {'login': 'israa-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/2?v=4'},
      'assignees': [
        {'login': 'israa-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/2?v=4'},
        {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      ],
      'labels': [
        {'name': 'bug', 'color': 'ee0701'},
        {'name': 'high', 'color': 'd93f0b'},
        {'name': 'backend', 'color': '1d76db'},
      ],
      'created_at': _now.subtract(const Duration(days: 10)).toIso8601String(),
      'milestone': {
        'title': 'Sprint 12',
        'due_on': _now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      'priority': 'high',
      'body': 'Payment gateway requests are timing out after 30s. Affecting ~5% of orders.',
    },

    // ── No Deadline (yellow) ─────────────────────────────────
    {
      'number': 55,
      'title': 'Implement push notifications for order updates',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_mobile/issues/55',
      'html_url': 'https://github.com/Sellio-Squad/sellio_mobile/issues/55',
      'repo_name': 'sellio_mobile',
      'author': {'login': 'maria-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/3?v=4'},
      'assignees': [],
      'labels': [
        {'name': 'feature', 'color': '84b6eb'},
        {'name': 'medium', 'color': 'fbca04'},
      ],
      'created_at': _now.subtract(const Duration(days: 7)).toIso8601String(),
      'milestone': null,
      'priority': 'medium',
      'body': 'Users should receive push notifications when their order status changes.',
    },
    {
      'number': 60,
      'title': 'Seller dashboard analytics not loading on slow connections',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_admin/issues/60',
      'html_url': 'https://github.com/Sellio-Squad/sellio_admin/issues/60',
      'repo_name': 'sellio_admin',
      'author': {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      'assignees': [],
      'labels': [
        {'name': 'bug', 'color': 'ee0701'},
        {'name': 'performance', 'color': 'e4e669'},
      ],
      'created_at': _now.subtract(const Duration(days: 5)).toIso8601String(),
      'milestone': null,
      'priority': null,
      'body': 'The analytics page shows a blank screen on connections below 10 Mbps.',
    },
    {
      'number': 71,
      'title': 'Add dark mode to seller onboarding screens',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_mobile/issues/71',
      'html_url': 'https://github.com/Sellio-Squad/sellio_mobile/issues/71',
      'repo_name': 'sellio_mobile',
      'author': {'login': 'maria-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/3?v=4'},
      'assignees': [
        {'login': 'maria-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/3?v=4'},
      ],
      'labels': [
        {'name': 'enhancement', 'color': '84b6eb'},
        {'name': 'UI', 'color': 'c2e0c6'},
        {'name': 'low', 'color': '0e8a16'},
      ],
      'created_at': _now.subtract(const Duration(days: 3)).toIso8601String(),
      'milestone': null,
      'priority': 'low',
      'body': 'Dark mode support is missing from the seller onboarding flow.',
    },
    {
      'number': 76,
      'title': 'Write API documentation for auth endpoints',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_backend/issues/76',
      'html_url': 'https://github.com/Sellio-Squad/sellio_backend/issues/76',
      'repo_name': 'sellio_backend',
      'author': {'login': 'israa-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/2?v=4'},
      'assignees': [],
      'labels': [
        {'name': 'documentation', 'color': '0075ca'},
      ],
      'created_at': _now.subtract(const Duration(days: 2)).toIso8601String(),
      'milestone': null,
      'priority': null,
      'body': 'Auth endpoints lack OpenAPI documentation. Required for front-end teams.',
    },

    // ── Healthy (green) ──────────────────────────────────────
    {
      'number': 80,
      'title': 'Upgrade Flutter to 3.27 across all apps',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_mobile/issues/80',
      'html_url': 'https://github.com/Sellio-Squad/sellio_mobile/issues/80',
      'repo_name': 'sellio_mobile',
      'author': {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      'assignees': [
        {'login': 'abdo-essam', 'avatar_url': 'https://avatars.githubusercontent.com/u/1?v=4'},
      ],
      'labels': [
        {'name': 'chore', 'color': 'c5def5'},
        {'name': 'dependencies', 'color': '0075ca'},
      ],
      'created_at': _now.subtract(const Duration(days: 1)).toIso8601String(),
      'milestone': {
        'title': 'Sprint 13',
        'due_on': _now.add(const Duration(days: 10)).toIso8601String(),
      },
      'priority': null,
      'body': 'Flutter 3.27 brings significant performance improvements. Need to upgrade all three apps.',
    },
    {
      'number': 82,
      'title': 'Set up E2E testing pipeline with Maestro',
      'url': 'https://api.github.com/repos/Sellio-Squad/sellio_mobile/issues/82',
      'html_url': 'https://github.com/Sellio-Squad/sellio_mobile/issues/82',
      'repo_name': 'sellio_mobile',
      'author': {'login': 'maria-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/3?v=4'},
      'assignees': [
        {'login': 'maria-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/3?v=4'},
        {'login': 'israa-dev', 'avatar_url': 'https://avatars.githubusercontent.com/u/2?v=4'},
      ],
      'labels': [
        {'name': 'testing', 'color': 'bfd4f2'},
        {'name': 'ci/cd', 'color': 'e4e669'},
        {'name': 'medium', 'color': 'fbca04'},
      ],
      'created_at': _now.subtract(const Duration(hours: 18)).toIso8601String(),
      'milestone': {
        'title': 'Sprint 13',
        'due_on': _now.add(const Duration(days: 7)).toIso8601String(),
      },
      'priority': 'medium',
      'body': 'Implement automated E2E tests for critical user journeys using Maestro.',
    },
  ];

  @override
  Future<List<dynamic>> fetchOpenIssues({required String org}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _issues;
  }
}
