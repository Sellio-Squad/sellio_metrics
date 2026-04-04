import 'package:sellio_metrics/domain/entities/issue_entity.dart';

abstract class IssuesRepository {
  Future<List<IssueEntity>> fetchOpenIssues({required String org});
}
