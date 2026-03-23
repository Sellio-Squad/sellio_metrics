/// Presentation — MemberProvider
///
/// Depends on [MembersRepository] (interface, not concrete).
/// Fetches server-computed member active/inactive status.

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/member_status_entity.dart';
import 'package:sellio_metrics/domain/repositories/members_repository.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

@injectable
class MemberProvider extends ChangeNotifier {
  final MembersRepository _repository;

  MemberProvider(this._repository);

  List<MemberStatusEntity> _memberStatuses = [];
  bool _isLoading = false;
  String? _error;

  List<MemberStatusEntity> get memberStatuses => _memberStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount => _memberStatuses.where((m) => m.isActive).length;
  int get inactiveCount => _memberStatuses.where((m) => !m.isActive).length;

  /// Fetch member statuses for [repoFullNames].
  Future<void> fetchStatuses(List<String> repoFullNames) async {
    if (repoFullNames.isEmpty) {
      _memberStatuses = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _memberStatuses = await _repository.getMembersStatus();
    } catch (e, stack) {
      appLogger.error('MemberProvider', 'Error: $e', stack);
      _error = e.toString();
      _memberStatuses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
