import 'user_model.dart';

/// A review approval on a PR.
class ApprovalModel {
  final UserModel reviewer;
  final DateTime submittedAt;
  final String commitId;
  final String? note;

  const ApprovalModel({
    required this.reviewer,
    required this.submittedAt,
    required this.commitId,
    this.note,
  });

  factory ApprovalModel.fromJson(Map<String, dynamic> json) => ApprovalModel(
    reviewer: UserModel.fromJson(json['reviewer'] as Map<String, dynamic>),
    submittedAt: DateTime.parse(json['submitted_at'] as String),
    commitId: json['commit_id'] as String? ?? '',
    note: json['note'] as String?,
  );
}
