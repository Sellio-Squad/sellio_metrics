import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/data/models/repo/repo_model.dart';

extension RepoModelMapper on RepoModel {
  RepoInfo toEntity() {
    return RepoInfo(
      id: id,
      name: name,
      fullName: fullName,
      description: description,
    );
  }
}
