class RepoInfo {
  final String name;
  final String fullName;
  final String? description;

  const RepoInfo({
    required this.name,
    required this.fullName,
    this.description,
  });
}
