/// Domain Entity — MemberStatusEntity
///
/// Immutable value object with equality support.

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberStatusEntity &&
          runtimeType == other.runtimeType &&
          developer == other.developer &&
          avatarUrl == other.avatarUrl &&
          isActive == other.isActive &&
          lastActiveDate == other.lastActiveDate;

  @override
  int get hashCode => Object.hash(developer, avatarUrl, isActive, lastActiveDate);

  @override
  String toString() =>
      'MemberStatusEntity(developer: $developer, isActive: $isActive)';
}
