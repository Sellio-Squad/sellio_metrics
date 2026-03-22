import 'user_model.dart';

/// Aggregated comment data per author on a PR.
class CommentModel {
  final UserModel author;
  final DateTime? firstCommentAt;
  final DateTime? lastCommentAt;
  final int count;

  const CommentModel({
    required this.author,
    this.firstCommentAt,
    this.lastCommentAt,
    required this.count,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
    author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
    firstCommentAt: json['first_comment_at'] != null
        ? DateTime.parse(json['first_comment_at'] as String)
        : null,
    lastCommentAt: json['last_comment_at'] != null
        ? DateTime.parse(json['last_comment_at'] as String)
        : null,
    count: json['count'] as int? ?? 0,
  );
}
