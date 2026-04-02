import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/domain/repositories/review_repository.dart';

export 'review_provider.dart' show SlimPrEntry;

enum ReviewStatus { idle, loading, loaded, error }

@lazySingleton
class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _repository;

  ReviewProvider(this._repository);

  // ─── Data ───────────────────────────────────────────────────
  ReviewStatus _status = ReviewStatus.idle;
  ReviewEntity? _review;
  String _errorMessage = '';

  // Repos + PRs for dropdowns (loaded via single /api/review/meta request)
  List<RepoInfo> _repos = [];
  List<SlimPrEntry> _openPrs = [];
  bool _loadingMeta = false;

  // Selection state
  RepoInfo? _selectedRepo;
  SlimPrEntry? _selectedPr;

  // ─── Getters ────────────────────────────────────────────────
  ReviewStatus get status => _status;
  ReviewEntity? get review => _review;
  String get errorMessage => _errorMessage;
  List<RepoInfo> get repos => _repos;
  bool get loadingMeta => _loadingMeta;
  RepoInfo? get selectedRepo => _selectedRepo;
  SlimPrEntry? get selectedSlimPr => _selectedPr;

  /// PR entries filtered to the selected repository
  List<SlimPrEntry> get prsForSelectedRepo {
    if (_selectedRepo == null) return _openPrs;
    final repoName = _selectedRepo!.name.toLowerCase();
    return _openPrs
        .where((pr) => pr.repo.toLowerCase() == repoName)
        .toList();
  }

  bool get isLoading => _status == ReviewStatus.loading;
  bool get hasResult => _status == ReviewStatus.loaded && _review != null;
  bool get hasError => _status == ReviewStatus.error;
  bool get canReview => _selectedRepo != null && _selectedPr != null && !isLoading;

  // ─── ONE request — load repos + PRs for dropdowns ───────────
  Future<void> loadMeta() async {
    if (_loadingMeta || _repos.isNotEmpty) return;
    _loadingMeta = true;
    notifyListeners();

    try {
      final meta = await _repository.fetchMeta();

      final rawRepos = meta['repos'] as List<dynamic>? ?? [];
      _repos = rawRepos
          .whereType<Map<String, dynamic>>()
          .map((r) => RepoInfo(
        id: r['id'] as int? ?? 0,
        name: r['name'] as String? ?? '',
        fullName: r['fullName'] as String? ?? '',
      ))
          .toList();

      final rawPrs = meta['prs'] as List<dynamic>? ?? [];
      _openPrs = rawPrs.whereType<Map<String, dynamic>>().map((p) {
        return SlimPrEntry(
          prNumber:  p['prNumber']  as int?    ?? 0,
          title:     p['title']     as String? ?? '',
          author:    p['author']    as String? ?? '',
          owner:     p['owner']     as String? ?? '',
          repo:      p['repoName']  as String? ?? '',
          additions: p['additions'] as int?    ?? 0,
          deletions: p['deletions'] as int?    ?? 0,
          url:       p['url']       as String? ?? '',
        );
      }).toList();

      if (_selectedRepo == null && _repos.isNotEmpty) {
        _selectedRepo = _repos.first;
      }
    } catch (e, stack) {
      appLogger.error('ReviewProvider', 'Failed to load review meta: $e', stack);
    }

    _loadingMeta = false;
    notifyListeners();
  }

  // ─── Selection ──────────────────────────────────────────────
  void selectRepo(RepoInfo repo) {
    _selectedRepo = repo;
    _selectedPr = null;
    notifyListeners();
  }

  void selectSlimPr(SlimPrEntry pr) {
    _selectedPr = pr;
    notifyListeners();
  }

  // ─── External pre-fill (from PR details page) ────────────────
  void prefill({required String owner, required String repo, required int prNumber}) {
    _selectedRepo = _repos.firstWhere(
          (r) => r.name.toLowerCase() == repo.toLowerCase(),
      orElse: () => RepoInfo(id: 0, name: repo, fullName: '$owner/$repo'),
    );
    _selectedPr = _openPrs.firstWhere(
          (pr) => pr.prNumber == prNumber,
      orElse: () => SlimPrEntry(
        prNumber:  prNumber,
        title:     'PR #$prNumber',
        author:    '',
        owner:     owner,
        repo:      repo,
        additions: 0,
        deletions: 0,
        url:       'https://github.com/$owner/$repo/pull/$prNumber',
      ),
    );
    notifyListeners();
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
      // owner + repo come directly from the PR entry (set by backend)
      final owner = _selectedPr!.owner.isNotEmpty
          ? _selectedPr!.owner
          : _selectedRepo!.fullName.split('/').first;
      final repo  = _selectedPr!.repo.isNotEmpty
          ? _selectedPr!.repo
          : _selectedRepo!.name;

      _review = await _repository.reviewPr(
        owner: owner,
        repo:  repo,
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

// ─── Slim PR model (only what the dropdown needs) ────────────

class SlimPrEntry {
  final int prNumber;
  final String title;
  final String author;
  final String owner;
  final String repo;
  final int additions;
  final int deletions;
  final String url;

  const SlimPrEntry({
    required this.prNumber,
    required this.title,
    required this.author,
    required this.owner,
    required this.repo,
    required this.additions,
    required this.deletions,
    required this.url,
  });

  String get displayLabel => '#$prNumber · $title';
}
