library;
import '../../domain/entities/approval_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/diff_stats_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../models/pr_model.dart';
import '../../domain/entities/pr_entity.dart';

extension UserModelMapper on UserModel {
  UserEntity toEntity() => UserEntity(
        login: login,
        id: id,
        url: url,
        avatarUrl: avatarUrl,
      );
}

extension CommentModelMapper on CommentModel {
  CommentEntity toEntity() => CommentEntity(
        author: author.toEntity(),
        firstCommentAt: firstCommentAt,
        lastCommentAt: lastCommentAt,
        count: count,
      );
}

extension ApprovalModelMapper on ApprovalModel {
  ApprovalEntity toEntity() => ApprovalEntity(
        reviewer: reviewer.toEntity(),
        submittedAt: submittedAt,
        commitId: commitId,
        note: note,
      );
}

extension DiffStatsMapper on DiffStats {
  DiffStatsEntity toEntity() => DiffStatsEntity(
        additions: additions,
        deletions: deletions,
        changedFiles: changedFiles,
      );
}

extension PrModelMapper on PrModel {
  PrEntity toEntity() => PrEntity(
        prNumber: prNumber,
        url: url,
        title: title,
        openedAt: openedAt,
        headRef: headRef,
        baseRef: baseRef,
        creator: creator.toEntity(),
        assignees: assignees.map((a) => a.toEntity()).toList(),
        comments: comments.map((c) => c.toEntity()).toList(),
        approvals: approvals.map((a) => a.toEntity()).toList(),
        requiredApprovals: requiredApprovals,
        firstApprovedAt: firstApprovedAt,
        timeToFirstApprovalMinutes: timeToFirstApprovalMinutes,
        requiredApprovalsMetAt: requiredApprovalsMetAt,
        timeToRequiredApprovalsMinutes: timeToRequiredApprovalsMinutes,
        closedAt: closedAt,
        mergedAt: mergedAt,
        mergedBy: mergedBy?.toEntity(),
        week: week,
        status: status,
        diffStats: diffStats.toEntity(),
        labels: labels,
        milestone: milestone,
        draft: draft,
      );
}
