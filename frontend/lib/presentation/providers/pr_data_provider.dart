import 'package:flutter/material.dart';

import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/repo_info.dart';
import '../../domain/repositories/pr_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/logging/app_logger.dart';

enum DataLoadingStatus { loading, loaded, error }

class PrDataProvider extends ChangeNotifier {
  final PrRepository _repository;

  PrDataProvider({required PrRepository repository})
    : _repository = repository;

  // Current repos that have been selected
  List<RepoInfo> _selectedRepos = [];
  
  // Open PRs specifically fetched from the new endpoint
  List<PrEntity> _openPrs = [];
  DataLoadingStatus _openPrsStatus = DataLoadingStatus.loading;

  List<PrEntity> get openPrs => _openPrs;
  DataLoadingStatus get openPrsStatus => _openPrsStatus;

  /// Load only open PRs (state=open) directly from the org-wide Open PRs endpoint.
  Future<void> loadOpenPrs({List<RepoInfo>? repos}) async {
    final rs = repos ?? _selectedRepos;
    if (rs.isEmpty) {
      sl.get<AppLogger>().info('PrDataProvider', 'No repos set. Waiting for selection.');
      return;
    }

    _selectedRepos = List.from(rs);

    _openPrsStatus = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final parts = rs.first.fullName.split('/');
      final owner = parts.isNotEmpty ? parts.first : '';
      if (owner.isEmpty) throw Exception("Could not determine organization name.");

      // Fetch org-wide open PRs directly, no iteration needed.
      final prs = await _repository.fetchOpenPrs(org: owner);
      
      _openPrs = prs;
      _openPrsStatus = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _openPrsStatus = DataLoadingStatus.error;
      sl.get<AppLogger>().error('PrDataProvider', 'Error loading open PRs: $e', stack);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadOpenPrs();
  }
}
