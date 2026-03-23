class RepoModel {
  final String name;
  final String fullName;
  final String? description;

  const RepoModel({
    required this.name,
    required this.fullName,
    this.description,
  });

  factory RepoModel.fromJson(Map<String, dynamic> json) {
    return RepoModel(
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'full_name': fullName,
      'description': description,
    };
  }
}
