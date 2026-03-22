import 'package:injectable/injectable.dart';
import '../pr_data_source.dart';

@Injectable(as: PrDataSource, env: [Environment.dev])
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
      "diff_stats": {"additions": 1200, "deletions": 50, "changed_files": 14},
      "body": "Adds login screen. Ref SELL-105.",
    },
  ];

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _prs.where((pr) => pr['status'] == 'pending' || pr['status'] == 'approved').toList();
  }
}
