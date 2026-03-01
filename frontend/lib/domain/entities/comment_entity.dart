import 'user_entity.dart';

class CommentEntity {
  final UserEntity author;
  final DateTime? firstCommentAt;
  final DateTime? lastCommentAt;
  final int count;

  const CommentEntity({
    required this.author,
    this.firstCommentAt,
    this.lastCommentAt,
    required this.count,
  });
}