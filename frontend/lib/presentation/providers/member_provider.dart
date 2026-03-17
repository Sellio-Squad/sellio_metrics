/// Presentation — MemberProvider
///
/// Depends on [MembersRepository] (interface, not concrete).
/// Fetches server-computed member active/inactive status.
library;

import 'package:flutter/material.dart';
import '../../domain/entities/member_status_entity.dart';
import '../../domain/repositories/members_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/logging/app_logger.dart';

class MemberProvider extends ChangeNotifier {
  final MembersRepository _repository;

  MemberProvider({required MembersRepository repository})
      : _repository = repository;

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
      sl.get<AppLogger>().error('MemberProvider', 'Error: $e', stack);
      _error = e.toString();
      _memberStatuses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
