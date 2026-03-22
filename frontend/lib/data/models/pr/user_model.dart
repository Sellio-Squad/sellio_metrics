/// A GitHub user reference.
class UserModel {
  final String login;
  final int id;
  final String url;
  final String avatarUrl;

  const UserModel({
    required this.login,
    required this.id,
    required this.url,
    this.avatarUrl = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    login: json['login'] as String? ?? '',
    id: json['id'] as int? ?? 0,
    url: json['url'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String? ?? '',
  );
}
