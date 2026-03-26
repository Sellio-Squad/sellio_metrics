import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/domain/repositories/review_repository.dart';

enum ReviewStatus { idle, loading, loaded, error }

@lazySingleton
class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _repository;

  ReviewProvider(this._repository);

  ReviewStatus _status = ReviewStatus.idle;
  ReviewEntity? _review;
  String _errorMessage = '';

  // Form state
  String _selectedOwner = ApiConfig.defaultOrg;
  String _selectedRepo = ApiConfig.defaultRepo;
  int _prNumber = 1;

  // Getters
  ReviewStatus get status => _status;
  ReviewEntity? get review => _review;
  String get errorMessage => _errorMessage;
  String get selectedOwner => _selectedOwner;
  String get selectedRepo => _selectedRepo;
  int get prNumber => _prNumber;

  bool get isLoading => _status == ReviewStatus.loading;
  bool get hasResult => _status == ReviewStatus.loaded && _review != null;
  bool get hasError => _status == ReviewStatus.error;

  void setOwner(String value) {
    _selectedOwner = value.trim();
    notifyListeners();
  }

  void setRepo(String value) {
    _selectedRepo = value.trim();
    notifyListeners();
  }

  void setPrNumber(int value) {
    _prNumber = value;
    notifyListeners();
  }

  Future<void> runReview() async {
    if (_selectedOwner.isEmpty || _selectedRepo.isEmpty || _prNumber <= 0) {
      _status = ReviewStatus.error;
      _errorMessage = 'Please fill in all fields correctly.';
      notifyListeners();
      return;
    }

    _status = ReviewStatus.loading;
    _review = null;
    _errorMessage = '';
    notifyListeners();

    try {
      _review = await _repository.reviewPr(
        owner: _selectedOwner,
        repo: _selectedRepo,
        prNumber: _prNumber,
      );
      _status = ReviewStatus.loaded;
    } catch (e, stack) {
      _status = ReviewStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      appLogger.error('ReviewProvider', 'Error running review: $e', stack);
    }
    notifyListeners();
  }

  void reset() {
    _status = ReviewStatus.idle;
    _review = null;
    _errorMessage = '';
    notifyListeners();
  }
}
