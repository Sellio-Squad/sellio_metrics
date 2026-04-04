import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/domain/entities/ticket_entity.dart';
import 'package:sellio_metrics/domain/repositories/tickets_repository.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart'
    show DataLoadingStatus;

// ─── Source Filter ────────────────────────────────────────────

enum TicketSourceFilter { all, issue, projectItem, draft }

extension TicketSourceFilterLabel on TicketSourceFilter {
  String get label => switch (this) {
        TicketSourceFilter.all         => 'All',
        TicketSourceFilter.issue       => 'Issues',
        TicketSourceFilter.projectItem => 'Project Items',
        TicketSourceFilter.draft       => 'Drafts',
      };
}

// ─── Summary Metrics ─────────────────────────────────────────

class TicketSummaryMetrics {
  final int total;
  final int noDeadline;
  final int overdue;
  final int unassigned;
  final Map<String, int> perRepo;
  final int fromIssues;
  final int fromProjectItems;
  final int fromDrafts;

  const TicketSummaryMetrics({
    required this.total,
    required this.noDeadline,
    required this.overdue,
    required this.unassigned,
    required this.perRepo,
    required this.fromIssues,
    required this.fromProjectItems,
    required this.fromDrafts,
  });
}

// ─── Scrum Insight ────────────────────────────────────────────

class ScrumInsight {
  final String message;
  final TicketHealthStatus severity;

  const ScrumInsight({required this.message, required this.severity});
}

// ─── Provider ─────────────────────────────────────────────────

@lazySingleton
class TicketsProvider extends ChangeNotifier {
  final TicketsRepository _repository;

  TicketsProvider(this._repository);

  // ── State ──────────────────────────────────────────────────

  List<TicketEntity> _tickets = [];
  DataLoadingStatus _status = DataLoadingStatus.loading;

  String _searchTerm = '';
  String? _selectedRepo;
  String? _selectedAssignee;
  String? _selectedLabel;
  TicketSourceFilter _sourceFilter = TicketSourceFilter.all;

  // ── Getters ────────────────────────────────────────────────

  List<TicketEntity> get allTickets => _tickets;
  DataLoadingStatus get status => _status;
  String get searchTerm => _searchTerm;
  String? get selectedRepo => _selectedRepo;
  String? get selectedAssignee => _selectedAssignee;
  String? get selectedLabel => _selectedLabel;
  TicketSourceFilter get sourceFilter => _sourceFilter;

  List<TicketEntity> get filteredTickets {
    var result = _tickets.where((t) {
      // Source filter
      if (_sourceFilter != TicketSourceFilter.all) {
        final match = switch (_sourceFilter) {
          TicketSourceFilter.issue       => t.source == TicketSource.issue,
          TicketSourceFilter.projectItem => t.source == TicketSource.projectItem,
          TicketSourceFilter.draft       => t.source == TicketSource.draft,
          TicketSourceFilter.all         => true,
        };
        if (!match) return false;
      }
      // Search term
      if (_searchTerm.isNotEmpty) {
        final term = _searchTerm.toLowerCase();
        if (!t.title.toLowerCase().contains(term) &&
            !t.author.login.toLowerCase().contains(term)) {
          return false;
        }
      }
      // Repo filter
      if (_selectedRepo != null && t.repoName != _selectedRepo) return false;
      // Assignee filter
      if (_selectedAssignee != null) {
        if (!t.assignees.any((a) => a.login == _selectedAssignee)) return false;
      }
      // Label filter
      if (_selectedLabel != null) {
        if (!t.labels.any((l) => l.name == _selectedLabel)) return false;
      }
      return true;
    }).toList();

    // Sort: overdue → no deadline → healthy → draft
    result.sort((a, b) {
      int sourceOrder(TicketEntity t) => switch (t.source) {
            TicketSource.draft => 3,
            _ => switch (t.healthStatus) {
                TicketHealthStatus.overdue    => 0,
                TicketHealthStatus.noDeadline => 1,
                TicketHealthStatus.healthy    => 2,
              },
          };
      final cmp = sourceOrder(a).compareTo(sourceOrder(b));
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  TicketSummaryMetrics get summaryMetrics {
    final all = _tickets;
    final perRepo = <String, int>{};
    for (final t in all) {
      if (t.repoName.isNotEmpty) {
        perRepo[t.repoName] = (perRepo[t.repoName] ?? 0) + 1;
      }
    }
    return TicketSummaryMetrics(
      total:            all.length,
      noDeadline:       all.where((t) => !t.hasDeadline && t.source != TicketSource.draft).length,
      overdue:          all.where((t) => t.isOverdue).length,
      unassigned:       all.where((t) => t.isUnassigned).length,
      perRepo:          perRepo,
      fromIssues:       all.where((t) => t.source == TicketSource.issue).length,
      fromProjectItems: all.where((t) => t.source == TicketSource.projectItem).length,
      fromDrafts:       all.where((t) => t.source == TicketSource.draft).length,
    );
  }

  List<ScrumInsight> get scrumInsights {
    final insights = <ScrumInsight>[];
    final m = summaryMetrics;

    if (m.overdue > 0) {
      insights.add(ScrumInsight(
        message: '🔴 ${m.overdue} ticket${m.overdue > 1 ? 's are' : ' is'} overdue — sprint delivery at risk.',
        severity: TicketHealthStatus.overdue,
      ));
      final overdueByRepo = <String, int>{};
      for (final t in _tickets.where((t) => t.isOverdue)) {
        if (t.repoName.isNotEmpty) {
          overdueByRepo[t.repoName] = (overdueByRepo[t.repoName] ?? 0) + 1;
        }
      }
      for (final e in overdueByRepo.entries) {
        if (e.value >= 2) {
          insights.add(ScrumInsight(
            message: '🔴 ${e.value} overdue tickets concentrated in ${e.key}.',
            severity: TicketHealthStatus.overdue,
          ));
        }
      }
    }

    final issuesMissingDeadline = m.noDeadline;
    if (issuesMissingDeadline > 0) {
      insights.add(ScrumInsight(
        message: '⚠️ $issuesMissingDeadline ticket${issuesMissingDeadline > 1 ? 's have' : ' has'} no deadline — may impact sprint planning.',
        severity: TicketHealthStatus.noDeadline,
      ));
    }

    if (m.unassigned > 0) {
      insights.add(ScrumInsight(
        message: '👤 ${m.unassigned} ticket${m.unassigned > 1 ? 's are' : ' is'} unassigned — delegate before sprint ends.',
        severity: TicketHealthStatus.noDeadline,
      ));
    }

    if (m.fromDrafts > 0) {
      insights.add(ScrumInsight(
        message: '📝 ${m.fromDrafts} draft item${m.fromDrafts > 1 ? 's need' : ' needs'} to be converted to real issues.',
        severity: TicketHealthStatus.noDeadline,
      ));
    }

    if (insights.isEmpty && _tickets.isNotEmpty) {
      insights.add(ScrumInsight(
        message: '✅ All tickets have deadlines and are on track. Great sprint hygiene!',
        severity: TicketHealthStatus.healthy,
      ));
    }

    if (_tickets.isEmpty && _status == DataLoadingStatus.loaded) {
      insights.add(ScrumInsight(
        message: '✅ No open tickets. The team is in great shape!',
        severity: TicketHealthStatus.healthy,
      ));
    }

    return insights;
  }

  List<String> get availableRepos {
    final repos = _tickets
        .map((t) => t.repoName)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return repos;
  }

  List<String> get availableAssignees {
    final logins = <String>{};
    for (final t in _tickets) {
      for (final a in t.assignees) { logins.add(a.login); }
    }
    return logins.toList()..sort();
  }

  List<String> get availableLabels {
    final names = <String>{};
    for (final t in _tickets) {
      for (final l in t.labels) { names.add(l.name); }
    }
    return names.toList()..sort();
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> loadTickets() async {
    _status = DataLoadingStatus.loading;
    notifyListeners();
    try {
      final tickets = await _repository.fetchOpenTickets(org: ApiConfig.defaultOrg);
      _tickets = tickets;
      _status = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _status = DataLoadingStatus.error;
      appLogger.error('TicketsProvider', 'Error loading tickets: $e', stack);
    }
    notifyListeners();
  }

  Future<void> refresh() => loadTickets();

  void setSourceFilter(TicketSourceFilter f) {
    _sourceFilter = f;
    notifyListeners();
  }

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
    _sourceFilter = TicketSourceFilter.all;
    notifyListeners();
  }
}
