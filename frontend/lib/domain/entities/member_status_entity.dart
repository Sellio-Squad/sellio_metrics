class MemberStatusEntity {
  final String developer;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? lastActiveDate;

  const MemberStatusEntity({
    required this.developer,
    this.avatarUrl,
    required this.isActive,
    this.lastActiveDate,
  });
}
