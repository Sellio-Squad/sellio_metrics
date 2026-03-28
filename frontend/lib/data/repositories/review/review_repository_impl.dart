import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/review/review_data_source.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/domain/repositories/review_repository.dart';

@Injectable(as: ReviewRepository)
class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewDataSource _dataSource;

  ReviewRepositoryImpl(this._dataSource);

  @override
  Future<ReviewEntity> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    final data = await _dataSource.reviewPr(
      owner: owner,
      repo: repo,
      prNumber: prNumber,
    );
    return _mapToEntity(data);
  }

  ReviewEntity _mapToEntity(Map<String, dynamic> data) {
    final prMap = data['pr'] as Map<String, dynamic>;
    final reviewMap = data['review'] as Map<String, dynamic>;

    final pr = ReviewPrInfoEntity(
      number: prMap['number'] as int,
      title: prMap['title'] as String? ?? '',
      author: prMap['author'] as String? ?? '',
      url: prMap['url'] as String? ?? '',
      state: prMap['state'] as String? ?? '',
      additions: prMap['additions'] as int? ?? 0,
      deletions: prMap['deletions'] as int? ?? 0,
      changedFiles: prMap['changedFiles'] as int? ?? 0,
      createdAt: DateTime.tryParse(prMap['createdAt'] as String? ?? '') ??
          DateTime.now(),
      body: prMap['body'] as String?,
    );

    return ReviewEntity(
      pr: pr,
      prSummary: reviewMap['prSummary'] as String? ?? '',
      bugs: _parseFindings(reviewMap['bugs']),
      bestPractices: _parseFindings(reviewMap['bestPractices']),
      security: _parseFindings(reviewMap['security']),
      performance: _parseFindings(reviewMap['performance']),
      hasIssues: reviewMap['hasIssues'] as bool? ?? false,
      reviewedAt:
          DateTime.tryParse(data['reviewedAt'] as String? ?? '') ?? DateTime.now(),
      fromCache: data['fromCache'] as bool? ?? false,
      reviewMeta: data['reviewMeta'] != null
          ? ReviewMetaEntity.fromJson(data['reviewMeta'] as Map<String, dynamic>)
          : null,
    );
  }

  List<ReviewFindingEntity> _parseFindings(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((f) => ReviewFindingEntity(
              file: f['file'] as String? ?? 'unknown',
              line: f['line'] as int?,
              severity: ReviewSeverityX.fromString(f['severity'] as String? ?? 'info'),
              title: f['title'] as String? ?? 'Issue',
              description: f['description'] as String? ?? '',
              suggestion: f['suggestion'] as String?,
            ))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> fetchMeta() async {
    return _dataSource.fetchMeta();
  }
}
