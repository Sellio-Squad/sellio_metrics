library;

import '../models/pr_model.dart';
import '../../core/constants/app_constants.dart';

import 'local_data_source.dart';

/// Simple in-memory implementation of [MetricsDataSource] that returns
/// deterministic fake data for local development and UI testing.
class FakeMetricsDataSource implements MetricsDataSource {
  FakeMetricsDataSource();

  static final UserModel _alice = UserModel(
    login: 'alice',
    id: 1,
    url: 'https://github.com/alice',
    avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  );

  static final UserModel _bob = UserModel(
    login: 'bob',
    id: 2,
    url: 'https://github.com/bob',
    avatarUrl: 'https://avatars.githubusercontent.com/u/2?v=4',
  );

  static final UserModel _carol = UserModel(
    login: 'carol',
    id: 3,
    url: 'https://github.com/carol',
    avatarUrl: 'https://avatars.githubusercontent.com/u/3?v=4',
  );

  static final List<PrModel> _fakePrs = [
    PrModel(
      prNumber: 101,
      url: 'https://github.com/Sellio-Squad/sellio_mobile/pull/101',
      title: 'Add dashboard overview widgets',
      openedAt: DateTime.now().subtract(const Duration(days: 5)),
      headRef: 'feature/dashboard-overview',
      baseRef: 'main',
      creator: _alice,
      assignees: const [],
      comments: [
        CommentModel(
          author: _bob,
          firstCommentAt: DateTime.now().subtract(const Duration(days: 4)),
          lastCommentAt: DateTime.now().subtract(const Duration(days: 3)),
          count: 3,
        ),
      ],
      approvals: [
        ApprovalModel(
          reviewer: _carol,
          submittedAt: DateTime.now().subtract(const Duration(days: 2)),
          commitId: 'abc123',
          note: 'Looks great!',
        ),
      ],
      requiredApprovals: 2,
      firstApprovedAt: DateTime.now().subtract(const Duration(days: 2)),
      timeToFirstApprovalMinutes: 60,
      requiredApprovalsMetAt: DateTime.now().subtract(const Duration(days: 2)),
      timeToRequiredApprovalsMinutes: 60,
      closedAt: null,
      mergedAt: DateTime.now().subtract(const Duration(days: 1)),
      mergedBy: _carol,
      week: '2026-09',
      status: 'merged',
      diffStats: const DiffStats(
        additions: 420,
        deletions: 120,
        changedFiles: 12,
      ),
      labels: const ['feature', 'dashboard'],
      milestone: 'v1.0',
      draft: false,
    ),
    PrModel(
      prNumber: 102,
      url: 'https://github.com/Sellio-Squad/sellio_mobile/pull/102',
      title: 'Fix bottleneck calculation edge cases',
      openedAt: DateTime.now().subtract(const Duration(days: 3)),
      headRef: 'fix/bottleneck-edge-cases',
      baseRef: 'main',
      creator: _bob,
      assignees: const [],
      comments: [
        CommentModel(
          author: _alice,
          firstCommentAt: DateTime.now().subtract(const Duration(days: 2)),
          lastCommentAt: DateTime.now().subtract(const Duration(days: 2)),
          count: 1,
        ),
      ],
      approvals: [
        ApprovalModel(
          reviewer: _alice,
          submittedAt: DateTime.now().subtract(const Duration(days: 1)),
          commitId: 'def456',
          note: null,
        ),
      ],
      requiredApprovals: 1,
      firstApprovedAt: DateTime.now().subtract(const Duration(days: 1)),
      timeToFirstApprovalMinutes: 120,
      requiredApprovalsMetAt: DateTime.now().subtract(const Duration(days: 1)),
      timeToRequiredApprovalsMinutes: 120,
      closedAt: null,
      mergedAt: null,
      mergedBy: null,
      week: '2026-09',
      status: 'pending',
      diffStats: const DiffStats(additions: 80, deletions: 10, changedFiles: 5),
      labels: const ['fix', 'bottleneck'],
      milestone: 'v1.0',
      draft: false,
    ),
    PrModel(
      prNumber: 103,
      url: 'https://github.com/Sellio-Squad/sellio_mobile/pull/103',
      title: 'Refactor PR timeline widget',
      openedAt: DateTime.now().subtract(const Duration(days: 7)),
      headRef: 'refactor/timeline-widget',
      baseRef: 'main',
      creator: _carol,
      assignees: const [],
      comments: const [],
      approvals: const [],
      requiredApprovals: 2,
      firstApprovedAt: null,
      timeToFirstApprovalMinutes: null,
      requiredApprovalsMetAt: null,
      timeToRequiredApprovalsMinutes: null,
      closedAt: DateTime.now().subtract(const Duration(days: 6)),
      mergedAt: null,
      mergedBy: null,
      week: '2026-08',
      status: 'closed',
      diffStats: const DiffStats(
        additions: 150,
        deletions: 200,
        changedFiles: 8,
      ),
      labels: const ['refactor', 'ui'],
      milestone: null,
      draft: false,
    ),
  ];

  @override
  Future<List<PrModel>> fetchPullRequests(String owner, String repo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _fakePrs;
  }

  @override
  Future<List<RepoModel>> fetchRepositories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      RepoModel(
        name: ApiConfig.defaultRepo,
        fullName: '${ApiConfig.defaultOrg}/${ApiConfig.defaultRepo}',
        description: 'Fake repo for local metrics preview',
        htmlUrl:
            'https://github.com/${ApiConfig.defaultOrg}/${ApiConfig.defaultRepo}',
        isPrivate: false,
      ),
    ];
  }

  @override
  Future<List<dynamic>> calculateLeaderboard(
    List<Map<String, dynamic>> prData,
  ) async {
    final Map<String, _LeaderboardAccumulator> byDeveloper = {};

    _LeaderboardAccumulator _getOrCreate(String login, String avatarUrl) {
      return byDeveloper.putIfAbsent(
        login,
        () => _LeaderboardAccumulator(login: login, avatarUrl: avatarUrl),
      );
    }

    for (final pr in prData) {
      final status = pr['status'] as String? ?? '';
      final creator = pr['creator'] as Map<String, dynamic>? ?? {};
      final creatorLogin = creator['login'] as String? ?? 'unknown';
      final creatorAvatar = creator['avatar_url'] as String? ?? '';

      final diff = pr['diff_stats'] as Map<String, dynamic>? ?? {};
      final additions = diff['additions'] as int? ?? 0;
      final deletions = diff['deletions'] as int? ?? 0;

      final approvals = (pr['approvals'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final comments = (pr['comments'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final creatorAcc = _getOrCreate(creatorLogin, creatorAvatar);
      creatorAcc.prsCreated += 1;
      if (status == 'merged') {
        creatorAcc.prsMerged += 1;
      }
      creatorAcc.additions += additions;
      creatorAcc.deletions += deletions;

      for (final approval in approvals) {
        final reviewer = approval['reviewer'] as Map<String, dynamic>? ?? {};
        final reviewerLogin = reviewer['login'] as String? ?? 'unknown';
        final reviewerAvatar = reviewer['avatar_url'] as String? ?? '';
        final acc = _getOrCreate(reviewerLogin, reviewerAvatar);
        acc.reviewsGiven += 1;
      }

      for (final comment in comments) {
        final author = comment['author'] as Map<String, dynamic>? ?? {};
        final authorLogin = author['login'] as String? ?? 'unknown';
        final authorAvatar = author['avatar_url'] as String? ?? '';
        final acc = _getOrCreate(authorLogin, authorAvatar);
        acc.commentsGiven += 1;
      }
    }

    for (final acc in byDeveloper.values) {
      acc.totalScore =
          (acc.prsCreated * LeaderboardWeights.prsCreated) +
          (acc.prsMerged * LeaderboardWeights.prsMerged) +
          (acc.reviewsGiven * LeaderboardWeights.reviewsGiven) +
          (acc.commentsGiven * LeaderboardWeights.commentsGiven);
    }

    final entries = byDeveloper.values.toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return entries
        .map(
          (e) => {
            'developer': e.login,
            'avatarUrl': e.avatarUrl,
            'prsCreated': e.prsCreated,
            'prsMerged': e.prsMerged,
            'reviewsGiven': e.reviewsGiven,
            'commentsGiven': e.commentsGiven,
            'additions': e.additions,
            'deletions': e.deletions,
            'totalScore': e.totalScore,
          },
        )
        .toList();
  }

  @override
  Future<List<dynamic>> getMemberStatuses(
    List<Map<String, dynamic>> prData,
  ) async {
    final Map<String, Map<String, dynamic>> statuses = {
      _alice.login: {'avatarUrl': _alice.avatarUrl, 'lastActiveDate': null},
      _bob.login: {'avatarUrl': _bob.avatarUrl, 'lastActiveDate': null},
      _carol.login: {'avatarUrl': _carol.avatarUrl, 'lastActiveDate': null},
    };

    void updateActivity(String login, String avatarUrl, String? dateStr) {
      if (dateStr == null) return;
      final entry = statuses.putIfAbsent(
        login,
        () => {'avatarUrl': avatarUrl, 'lastActiveDate': null},
      );
      final current = entry['lastActiveDate'] as String?;
      if (current == null ||
          DateTime.parse(dateStr).isAfter(DateTime.parse(current))) {
        entry['lastActiveDate'] = dateStr;
      }
    }

    for (final pr in prData) {
      final creator = pr['creator'] as Map<String, dynamic>? ?? {};
      final openedAt = pr['opened_at'] as String?;
      updateActivity(
        creator['login'] ?? '',
        creator['avatar_url'] ?? '',
        openedAt,
      );

      final approvals = (pr['approvals'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final a in approvals) {
        final rev = a['reviewer'] as Map<String, dynamic>? ?? {};
        updateActivity(
          rev['login'] ?? '',
          rev['avatar_url'] ?? '',
          a['submitted_at'] as String?,
        );
      }

      final comments = (pr['comments'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final c in comments) {
        final author = c['author'] as Map<String, dynamic>? ?? {};
        final dates = [
          c['first_comment_at'],
          c['last_comment_at'],
        ].whereType<String>().toList();
        dates.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
        updateActivity(
          author['login'] ?? '',
          author['avatar_url'] ?? '',
          dates.isNotEmpty ? dates.first : null,
        );
      }
    }

    return statuses.entries.map((e) {
      return {
        'developer': e.key,
        'avatarUrl': e.value['avatarUrl'],
        'isActive': e.value['lastActiveDate'] != null,
        'lastActiveDate': e.value['lastActiveDate'],
      };
    }).toList()..sort((a, b) {
      final aActive = a['isActive'] as bool;
      final bActive = b['isActive'] as bool;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      if (aActive && bActive) {
        final da = DateTime.parse(a['lastActiveDate'] as String);
        final db = DateTime.parse(b['lastActiveDate'] as String);
        return db.compareTo(da);
      }
      return (a['developer'] as String).compareTo(b['developer'] as String);
    });
  }
}

class _LeaderboardAccumulator {
  _LeaderboardAccumulator({required this.login, required this.avatarUrl});

  final String login;
  final String avatarUrl;
  double prsCreated = 0;
  double prsMerged = 0;
  double reviewsGiven = 0;
  double commentsGiven = 0;
  double additions = 0;
  double deletions = 0;
  double totalScore = 0;
}
