import 'user_entity.dart';

class ApprovalEntity {
  final UserEntity reviewer;
  final DateTime submittedAt;
  final String commitId;
  final String? note;

  const ApprovalEntity({
    required this.reviewer,
    required this.submittedAt,
    required this.commitId,
    this.note,
  });
}