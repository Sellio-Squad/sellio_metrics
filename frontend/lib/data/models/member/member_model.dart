class MemberModel {
  final String developer;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? lastActiveDate;

  const MemberModel({
    required this.developer,
    this.avatarUrl,
    required this.isActive,
    this.lastActiveDate,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      developer: json['developer'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      lastActiveDate: json['lastActiveDate'] != null 
          ? DateTime.tryParse(json['lastActiveDate'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'developer': developer,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'lastActiveDate': lastActiveDate?.toIso8601String(),
    };
  }
}
