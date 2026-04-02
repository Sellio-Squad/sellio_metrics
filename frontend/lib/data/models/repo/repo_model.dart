class RepoModel {
  final int id;
  final String name;
  final String fullName;
  final String? description;

  const RepoModel({
    required this.id,
    required this.name,
    required this.fullName,
    this.description,
  });

  factory RepoModel.fromJson(Map<String, dynamic> json) {
    return RepoModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'full_name': fullName,
      'description': description,
    };
  }
}
