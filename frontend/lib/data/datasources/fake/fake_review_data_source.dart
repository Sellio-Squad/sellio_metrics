import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/review/review_data_source.dart';

@Injectable(as: ReviewDataSource, env: [Environment.dev])
class FakeReviewDataSource implements ReviewDataSource {
  @override
  Future<Map<String, dynamic>> fetchMeta() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    return {
      'repos': [
        {'name': 'sellio_mobile', 'fullName': 'Sellio-Squad/sellio_mobile'},
        {'name': 'sellio_backend', 'fullName': 'Sellio-Squad/sellio_backend'},
        {'name': 'sellio_metrics', 'fullName': 'Sellio-Squad/sellio_metrics'},
      ],
      'prs': [
        {
          'prNumber': 1,
          'title': 'feat: init login screen',
          'author': 'alice',
          'owner': 'Sellio-Squad',
          'repoName': 'sellio_mobile',
          'additions': 1200,
          'deletions': 50,
          'url': 'https://github.com/Sellio-Squad/sellio_mobile/pull/1',
        },
        {
          'prNumber': 42,
          'title': 'fix: crash on checkout',
          'author': 'bob',
          'owner': 'Sellio-Squad',
          'repoName': 'sellio_backend',
          'additions': 10,
          'deletions': 5,
          'url': 'https://github.com/Sellio-Squad/sellio_backend/pull/42',
        },
        {
          'prNumber': 105,
          'title': 'refactor: state management',
          'author': 'charlie',
          'owner': 'Sellio-Squad',
          'repoName': 'sellio_metrics',
          'additions': 450,
          'deletions': 120,
          'url': 'https://github.com/Sellio-Squad/sellio_metrics/pull/105',
        }
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate AI review time
    return {
      'pr': {
        'number': prNumber,
        'title': 'Fake PR #$prNumber from $repo',
        'author': 'demo_user',
        'url': 'https://github.com/$owner/$repo/pull/$prNumber',
        'state': 'open',
        'additions': 150,
        'deletions': 20,
        'changedFiles': 3,
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'body': 'This is a simulated PR description for testing the code review feature.'
      },
      'review': {
        'prSummary': 'This PR refactors the authentication logic and introduces a new login UI. Overall code structure is solid, but there are some critical issues and optimizations that need attention before merging.',
        'bugs': [
          {
            'file': 'lib/auth_service.dart',
            'line': 45,
            'severity': 'critical',
            'title': 'Uncaught exception in login flow',
            'description': 'If the network request fails, the exception is not caught and will crash the app.',
            'suggestion': 'Wrap the API call in a try-catch block and handle DioException explicitly.',
          },
          {
            'file': 'lib/auth_service.dart',
            'line': 72,
            'severity': 'warning',
            'title': 'Potential null pointer',
            'description': 'User object might be null if the token is invalid or parsing fails.',
            'suggestion': 'Add a null check before accessing user.id.',
          }
        ],
        'bestPractices': [
          {
            'file': 'lib/login_screen.dart',
            'line': 120,
            'severity': 'info',
            'title': 'Magic numbers used for padding',
            'description': 'Hardcoded 16.0 for padding instead of using design system tokens.',
            'suggestion': 'Replace 16.0 with AppSpacing.md.',
          }
        ],
        'security': [
          {
            'file': 'lib/auth_service.dart',
            'line': 25,
            'severity': 'critical',
            'title': 'Hardcoded API key',
            'description': 'Found a hardcoded API key in the source code.',
            'suggestion': 'Move the key to an environment variable or secure storage.',
          }
        ],
        'performance': [
          {
            'file': 'lib/login_screen.dart',
            'line': 50,
            'severity': 'warning',
            'title': 'Unnecessary rebuilds',
            'description': 'Using set state in the text field onChange will rebuild the entire screen on every keystroke.',
            'suggestion': 'Extract the text field into its own StatefulWidget or use a string controller with a value notifier.',
          }
        ],
        'hasIssues': true,
      },
      'reviewedAt': DateTime.now().toIso8601String(),
      'fromCache': false,
      'reviewMeta': {
        'totalFiles': 3,
        'filesReviewed': 3,
        'filesSkipped': 0,
        'totalCharsReviewed': 25000,
        'charBudget': 30000,
      }
    };
  }
}
