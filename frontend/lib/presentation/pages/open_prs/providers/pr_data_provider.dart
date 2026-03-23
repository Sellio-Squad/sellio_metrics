import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/repositories/pr_repository.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

enum DataLoadingStatus { loading, loaded, error }

@lazySingleton
class PrDataProvider extends ChangeNotifier {
  final PrRepository _repository;

  PrDataProvider(this._repository);
  
  // Open PRs specifically fetched from the new endpoint
  List<PrEntity> _openPrs = [];
  DataLoadingStatus _openPrsStatus = DataLoadingStatus.loading;

  List<PrEntity> get openPrs => _openPrs;
  DataLoadingStatus get openPrsStatus => _openPrsStatus;

  /// Load only open PRs (state=open) directly from the org-wide Open PRs endpoint.
  Future<void> loadOpenPrs() async {
    _openPrsStatus = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final owner = ApiConfig.defaultOrg;

      // Fetch org-wide open PRs directly, no iteration needed.
      final prs = await _repository.fetchOpenPrs(org: owner);
      
      _openPrs = prs;
      _openPrsStatus = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _openPrsStatus = DataLoadingStatus.error;
      appLogger.error('PrDataProvider', 'Error loading open PRs: $e', stack);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadOpenPrs();
  }
}
