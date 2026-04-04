import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/domain/entities/issue_entity.dart';
import 'package:sellio_metrics/domain/repositories/issues_repository.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart'
    show DataLoadingStatus;

// ─── Summary Metrics ─────────────────────────────────────────

class IssueSummaryMetrics {
  final int total;
  final int noDeadline;
  final int overdue;
  final int unassigned;
  final Map<String, int> perRepo;

  const IssueSummaryMetrics({
    required this.total,
    required this.noDeadline,
    required this.overdue,
    required this.unassigned,
    required this.perRepo,
  });
}

// ─── Scrum Insight ───────────────────────────────────────────

class ScrumInsight {
  final String message;
  final IssueHealthStatus severity; // overdue=red, noDeadline=yellow, healthy=green

  const ScrumInsight({required this.message, required this.severity});
}

// ─── Provider ────────────────────────────────────────────────

@injectable
class IssuesProvider extends ChangeNotifier {
  final IssuesRepository _repository;

  IssuesProvider(this._repository);

  // ── State ─────────────────────────────────────────────────

  List<IssueEntity> _issues = [];
  DataLoadingStatus _status = DataLoadingStatus.loading;

  String _searchTerm = '';
  String? _selectedRepo;
  String? _selectedAssignee;
  String? _selectedLabel;

  // ── Getters ───────────────────────────────────────────────

  List<IssueEntity> get allIssues => _issues;
  DataLoadingStatus get status => _status;
  String get searchTerm => _searchTerm;
  String? get selectedRepo => _selectedRepo;
  String? get selectedAssignee => _selectedAssignee;
  String? get selectedLabel => _selectedLabel;

  /// Sorted & filtered list: overdue → no deadline → healthy.
  List<IssueEntity> get filteredIssues {
    var result = _issues.where((issue) {
      // Search term
      if (_searchTerm.isNotEmpty) {
        final term = _searchTerm.toLowerCase();
        if (!issue.title.toLowerCase().contains(term) &&
            !issue.author.login.toLowerCase().contains(term)) {
          return false;
        }
      }
      // Repo filter
      if (_selectedRepo != null && issue.repoName != _selectedRepo) return false;
      // Assignee filter
      if (_selectedAssignee != null) {
        final hasAssignee = issue.assignees.any((a) => a.login == _selectedAssignee);
        if (!hasAssignee) return false;
      }
      // Label filter
      if (_selectedLabel != null) {
        final hasLabel = issue.labels.any((l) => l.name == _selectedLabel);
        if (!hasLabel) return false;
      }
      return true;
    }).toList();

    // Sort: overdue first → no deadline → healthy; within group sort by created desc
    result.sort((a, b) {
      final statusOrder = {
        IssueHealthStatus.overdue: 0,
        IssueHealthStatus.noDeadline: 1,
        IssueHealthStatus.healthy: 2,
      };
      final cmp = statusOrder[a.healthStatus]!.compareTo(statusOrder[b.healthStatus]!);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  IssueSummaryMetrics get summaryMetrics {
    final all = _issues;
    final perRepo = <String, int>{};
    for (final issue in all) {
      perRepo[issue.repoName] = (perRepo[issue.repoName] ?? 0) + 1;
    }
    return IssueSummaryMetrics(
      total: all.length,
      noDeadline: all.where((i) => !i.hasDeadline).length,
      overdue: all.where((i) => i.isOverdue).length,
      unassigned: all.where((i) => i.isUnassigned).length,
      perRepo: perRepo,
    );
  }

  List<ScrumInsight> get scrumInsights {
    final insights = <ScrumInsight>[];
    final metrics = summaryMetrics;

    // Overdue
    if (metrics.overdue > 0) {
      insights.add(ScrumInsight(
        message: '🔴 ${metrics.overdue} ticket${metrics.overdue > 1 ? 's are' : ' is'} overdue — sprint delivery is at risk.',
        severity: IssueHealthStatus.overdue,
      ));

      // Per-repo overdue breakdown
      final overdueByRepo = <String, int>{};
      for (final issue in _issues.where((i) => i.isOverdue)) {
        overdueByRepo[issue.repoName] = (overdueByRepo[issue.repoName] ?? 0) + 1;
      }
      for (final entry in overdueByRepo.entries) {
        if (entry.value >= 2) {
          insights.add(ScrumInsight(
            message: '🔴 High concentration of overdue tickets (${entry.value}) in ${entry.key}.',
            severity: IssueHealthStatus.overdue,
          ));
        }
      }
    }

    // No deadline
    if (metrics.noDeadline > 0) {
      insights.add(ScrumInsight(
        message: '⚠️ ${metrics.noDeadline} ticket${metrics.noDeadline > 1 ? 's have' : ' has'} no deadline and may delay sprint planning.',
        severity: IssueHealthStatus.noDeadline,
      ));
    }

    // Unassigned
    if (metrics.unassigned > 0) {
      insights.add(ScrumInsight(
        message: '👤 ${metrics.unassigned} ticket${metrics.unassigned > 1 ? 's are' : ' is'} unassigned — consider delegating before the sprint ends.',
        severity: IssueHealthStatus.noDeadline,
      ));
    }

    // No issues at all
    if (_issues.isEmpty && _status == DataLoadingStatus.loaded) {
      insights.add(ScrumInsight(
        message: '✅ No open issues found. The team is in great shape!',
        severity: IssueHealthStatus.healthy,
      ));
    }

    // All healthy
    if (insights.isEmpty && _issues.isNotEmpty) {
      insights.add(ScrumInsight(
        message: '✅ All issues have deadlines and are on track. Great sprint hygiene!',
        severity: IssueHealthStatus.healthy,
      ));
    }

    return insights;
  }

  /// All unique repo names from loaded issues.
  List<String> get availableRepos {
    final repos = _issues.map((i) => i.repoName).toSet().toList()..sort();
    return repos;
  }

  /// All unique assignee logins.
  List<String> get availableAssignees {
    final logins = <String>{};
    for (final issue in _issues) {
      for (final a in issue.assignees) {
        logins.add(a.login);
      }
    }
    return logins.toList()..sort();
  }

  /// All unique label names.
  List<String> get availableLabels {
    final names = <String>{};
    for (final issue in _issues) {
      for (final l in issue.labels) {
        names.add(l.name);
      }
    }
    return names.toList()..sort();
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> loadIssues() async {
    _status = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final issues = await _repository.fetchOpenIssues(org: ApiConfig.defaultOrg);
      _issues = issues;
      _status = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _status = DataLoadingStatus.error;
      appLogger.error('IssuesProvider', 'Error loading issues: $e', stack);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadIssues();

  void setSearchTerm(String term) {
    _searchTerm = term;
    notifyListeners();
  }

  void setRepoFilter(String? repo) {
    _selectedRepo = repo;
    notifyListeners();
  }

  void setAssigneeFilter(String? assignee) {
    _selectedAssignee = assignee;
    notifyListeners();
  }

  void setLabelFilter(String? label) {
    _selectedLabel = label;
    notifyListeners();
  }

  void clearFilters() {
    _searchTerm = '';
    _selectedRepo = null;
    _selectedAssignee = null;
    _selectedLabel = null;
    notifyListeners();
  }
}
