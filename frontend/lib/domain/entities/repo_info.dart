class RepoInfo {
  final int id;
  final String name;
  final String fullName;
  final String? description;

  const RepoInfo({
    required this.id,
    required this.name,
    required this.fullName,
    this.description,
  });
}
