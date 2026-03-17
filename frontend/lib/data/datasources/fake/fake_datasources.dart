/// Data — Fake Datasources (USE_FAKE_DATA mode)
///
/// In-memory implementations of all datasource interfaces for local testing.
/// Implement the same interfaces as remote datasources — zero runtime coupling.
library;

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/repo_info.dart';
import '../leaderboard_data_source.dart';
import '../members_data_source.dart';
import '../repos_data_source.dart';
import '../pr_data_source.dart';


// ─── Fake Repos ──────────────────────────────────────────────

class FakeReposDataSource implements ReposDataSource {
  @override
  Future<List<RepoInfo>> fetchRepositories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      RepoInfo(
        name: ApiConfig.defaultRepo,
        fullName: '${ApiConfig.defaultOrg}/${ApiConfig.defaultRepo}',
        description: 'Fake repo for local metrics preview',
      ),
    ];
  }
}

// ─── Fake Leaderboard ────────────────────────────────────────

class FakeLeaderboardDataSource implements LeaderboardDataSource {
  static final _entries = [
    LeaderboardEntry(
      developer: 'alice',
      avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
      prsCreated: 12,
      prsMerged: 10,
      commentsGiven: 15,
      additions: 1200,
      deletions: 400,
      totalScore: 62.0,
    ),
    LeaderboardEntry(
      developer: 'bob',
      avatarUrl: 'https://avatars.githubusercontent.com/u/2?v=4',
      prsCreated: 8,
      prsMerged: 6,
      commentsGiven: 9,
      additions: 800,
      deletions: 200,
      totalScore: 45.0,
    ),
    LeaderboardEntry(
      developer: 'carol',
      avatarUrl: 'https://avatars.githubusercontent.com/u/3?v=4',
      prsCreated: 5,
      prsMerged: 5,
      commentsGiven: 5,
      additions: 300,
      deletions: 100,
      totalScore: 30.0,
    ),
  ];

  @override
  Future<List<dynamic>> fetchLeaderboard() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _entries
        .map(
          (e) => {
            'developer': e.developer,
            'avatarUrl': e.avatarUrl,
            'prsCreated': e.prsCreated,
            'prsMerged': e.prsMerged,
            'commentsGiven': e.commentsGiven,
            'additions': e.additions,
            'deletions': e.deletions,
            'totalScore': e.totalScore,
          },
        )
        .toList();
  }
}

// ─── Fake Members ─────────────────────────────────────────────

class FakeMembersDataSource implements MembersDataSource {
  static final _members = [
    {
      'developer': 'alice',
      'avatarUrl': 'https://avatars.githubusercontent.com/u/1?v=4',
      'isActive': true,
      'lastActiveDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'developer': 'bob',
      'avatarUrl': 'https://avatars.githubusercontent.com/u/2?v=4',
      'isActive': true,
      'lastActiveDate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'developer': 'carol',
      'avatarUrl': 'https://avatars.githubusercontent.com/u/3?v=4',
      'isActive': false,
      'lastActiveDate': DateTime.now().subtract(const Duration(days: 35)).toIso8601String(),
    },
  ];

  @override
  Future<List<dynamic>> fetchMembersStatus() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _members;
  }
}

// ─── Fake PRs ────────────────────────────────────────────────

class FakePrDataSource implements PrDataSource {
  static final _prs = [
    {
      "pr_number": 1,
      "url": "https://github.com/Sellio-Squad/sellio_mobile/pull/1",
      "title": "feat: init login screen",
      "opened_at": DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      "head_ref": "feat/login",
      "base_ref": "develop",
      "creator": {"id": 1, "login": "alice", "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4"},
      "assignees": [],
      "comments": [],
      "approvals": [],
      "required_approvals": 2,
      "first_approved_at": null,
      "time_to_first_approval_minutes": null,
      "required_approvals_met_at": null,
      "closed_at": null,
      "merged_at": null,
      "merged_by": null,
      "week": "2026-W10",
      "status": "pending",
      "labels": ["feature"],
      "milestone": null,
      "draft": false,
      "diff_stats": {"additions": 120, "deletions": 5, "changed_files": 4},
    },
    {
      "pr_number": 2,
      "url": "https://github.com/Sellio-Squad/sellio_mobile/pull/2",
      "title": "fix: crash on launch",
      "opened_at": DateTime.now().subtract(const Duration(hours: 30)).toIso8601String(),
      "head_ref": "fix/crash-launch",
      "base_ref": "develop",
      "creator": {"id": 2, "login": "bob", "avatar_url": "https://avatars.githubusercontent.com/u/2?v=4"},
      "assignees": [],
      "comments": [],
      "approvals": [
        {
          "reviewer": {"id": 3, "login": "carol", "avatar_url": "https://avatars.githubusercontent.com/u/3?v=4"},
          "submitted_at": DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
          "commit_id": "abc123",
        }
      ],
      "required_approvals": 2,
      "first_approved_at": DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
      "time_to_first_approval_minutes": 20.0 * 60,
      "required_approvals_met_at": null,
      "closed_at": null,
      "merged_at": null,
      "merged_by": null,
      "week": "2026-W10",
      "status": "approved",
      "labels": ["fix"],
      "milestone": null,
      "draft": false,
      "diff_stats": {"additions": 10, "deletions": 2, "changed_files": 1},
    },
    {
      "pr_number": 3,
      "url": "https://github.com/Sellio-Squad/sellio_mobile/pull/3",
      "title": "chore: cleanup unused imports",
      "opened_at": DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      "head_ref": "chore/cleanup",
      "base_ref": "develop",
      "creator": {"id": 3, "login": "carol", "avatar_url": "https://avatars.githubusercontent.com/u/3?v=4"},
      "assignees": [],
      "comments": [],
      "approvals": [],
      "required_approvals": 2,
      "first_approved_at": null,
      "time_to_first_approval_minutes": null,
      "required_approvals_met_at": null,
      "closed_at": DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
      "merged_at": DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
      "merged_by": {"id": 1, "login": "alice", "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4"},
      "week": "2026-W09",
      "status": "merged",
      "labels": ["chore"],
      "milestone": null,
      "draft": false,
      "diff_stats": {"additions": 5, "deletions": 30, "changed_files": 3},
    },
  ];

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _prs.where((pr) => pr['status'] == 'pending' || pr['status'] == 'approved').toList();
  }
}

