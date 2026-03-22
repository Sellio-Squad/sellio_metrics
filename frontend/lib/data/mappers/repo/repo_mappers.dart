import '../../../domain/entities/repo_info.dart';
import '../../models/repo/repo_model.dart';

extension RepoModelMapper on RepoModel {
  RepoInfo toEntity() {
    return RepoInfo(
      name: name,
      fullName: fullName,
      description: description,
    );
  }
}
