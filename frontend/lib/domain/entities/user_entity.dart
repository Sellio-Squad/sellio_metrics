
class UserEntity {
  final String login;
  final int id;
  final String url;
  final String avatarUrl;

  const UserEntity({
    required this.login,
    required this.id,
    this.url = '',
    this.avatarUrl = '',
  });
}