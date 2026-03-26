import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/domain/entities/diff_stats_entity.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/domain/entities/user_entity.dart';
import 'package:sellio_metrics/domain/repositories/pr_repository.dart';
import 'package:sellio_metrics/domain/repositories/repos_repository.dart';
import 'package:sellio_metrics/domain/repositories/review_repository.dart';

enum ReviewStatus { idle, loading, loaded, error }

@lazySingleton
class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _repository;
  final ReposRepository _reposRepository;
  final PrRepository _prRepository;

  ReviewProvider(this._repository, this._reposRepository, this._prRepository);

  // ─── Data ───────────────────────────────────────────────────
  ReviewStatus _status = ReviewStatus.idle;
  ReviewEntity? _review;
  String _errorMessage = '';

  // Repos + PRs for dropdowns
  List<RepoInfo> _repos = [];
  List<PrEntity> _openPrs = [];
  bool _loadingMeta = false;

  // Selection state
  RepoInfo? _selectedRepo;
  PrEntity? _selectedPr;

  // ─── Getters ────────────────────────────────────────────────
  ReviewStatus get status => _status;
  ReviewEntity? get review => _review;
  String get errorMessage => _errorMessage;
  List<RepoInfo> get repos => _repos;
  bool get loadingMeta => _loadingMeta;
  RepoInfo? get selectedRepo => _selectedRepo;
  PrEntity? get selectedPr => _selectedPr;

  /// PRs filtered to those belonging to the selected repo
  List<PrEntity> get prsForSelectedRepo {
    if (_selectedRepo == null) return [];
    final repoName = _selectedRepo!.name.toLowerCase();
    return _openPrs
        .where((pr) => pr.repoName.toLowerCase().contains(repoName))
        .toList();
  }

  bool get isLoading => _status == ReviewStatus.loading;
  bool get hasResult => _status == ReviewStatus.loaded && _review != null;
  bool get hasError => _status == ReviewStatus.error;
  bool get canReview => _selectedRepo != null && _selectedPr != null && !isLoading;

  // ─── Init: load repos + open PRs ────────────────────────────
  Future<void> loadMeta() async {
    if (_loadingMeta || _repos.isNotEmpty) return;
    _loadingMeta = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _reposRepository.getRepositories(),
        _prRepository.fetchOpenPrs(org: ApiConfig.defaultOrg),
      ]);

      _repos = results[0] as List<RepoInfo>;
      _openPrs = results[1] as List<PrEntity>;

      // Auto-select first repo
      if (_selectedRepo == null && _repos.isNotEmpty) {
        _selectedRepo = _repos.first;
      }
    } catch (e, stack) {
      appLogger.error('ReviewProvider', 'Failed to load repos/PRs: $e', stack);
    }

    _loadingMeta = false;
    notifyListeners();
  }

  // ─── Selection ──────────────────────────────────────────────
  void selectRepo(RepoInfo repo) {
    _selectedRepo = repo;
    _selectedPr = null; // reset PR when repo changes
    notifyListeners();
  }

  void selectPr(PrEntity pr) {
    _selectedPr = pr;
    notifyListeners();
  }

  // ─── External pre-fill (called from PR details page) ────────
  void prefill({required String owner, required String repo, required int prNumber}) {
    // Match repo by name
    final matchedRepo = _repos.firstWhere(
      (r) => r.name.toLowerCase() == repo.toLowerCase(),
      orElse: () => RepoInfo(
        name: repo,
        fullName: '$owner/$repo',
      ),
    );
    _selectedRepo = matchedRepo;

    // Match PR by number
    final matchedPr = _openPrs.firstWhere(
      (pr) => pr.prNumber == prNumber,
      orElse: () => _createFallbackPr(prNumber, owner, repo),
    );
    _selectedPr = matchedPr;

    notifyListeners();
  }

  PrEntity _createFallbackPr(int prNumber, String owner, String repo) {
    // Not in open PRs list — but we still store the number so the API call works
    return _selectedPr ??
        PrEntity(
          prNumber: prNumber,
          url: 'https://github.com/$owner/$repo/pull/$prNumber',
          title: 'PR #$prNumber',
          openedAt: DateTime.now(),
          headRef: '',
          baseRef: '',
          creator: const UserEntity(id: 0, login: '', avatarUrl: ''),
          assignees: const [],
          comments: const [],
          approvals: const [],
          requiredApprovals: 0,
          week: '',
          status: 'pending',
          diffStats: const DiffStatsEntity(
            additions: 0,
            deletions: 0,
            changedFiles: 0,
          ),
        );
  }

  // ─── Run Review ─────────────────────────────────────────────
  Future<void> runReview() async {
    if (_selectedRepo == null || _selectedPr == null) {
      _status = ReviewStatus.error;
      _errorMessage = 'Please select a repository and a pull request.';
      notifyListeners();
      return;
    }

    _status = ReviewStatus.loading;
    _review = null;
    _errorMessage = '';
    notifyListeners();

    try {
      final parts = _selectedRepo!.fullName.split('/');
      final owner = parts.isNotEmpty ? parts[0] : ApiConfig.defaultOrg;
      final repo = parts.length > 1 ? parts[1] : _selectedRepo!.name;

      _review = await _repository.reviewPr(
        owner: owner,
        repo: repo,
        prNumber: _selectedPr!.prNumber,
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
