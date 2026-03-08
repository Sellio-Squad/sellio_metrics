/// Presentation — MemberProvider
///
/// Depends on [MembersRepository] (interface, not concrete).
/// Fetches server-computed member active/inactive status.
library;

import 'package:flutter/foundation.dart';
import '../../domain/entities/member_status_entity.dart';
import '../../domain/repositories/members_repository.dart';

class MemberProvider extends ChangeNotifier {
  /// Depends on INTERFACE — satisfies Dependency Inversion Principle.
  final MembersRepository _repository;

  MemberProvider({required MembersRepository repository})
    : _repository = repository;

  List<MemberStatusEntity> _memberStatuses = [];
  bool _isLoading = false;
  String? _error;

  List<MemberStatusEntity> get memberStatuses => _memberStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch member statuses for [repoFullNames].
  /// Uses first selected repo — member activity is org-wide.
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
      final parts = repoFullNames.first.split('/');
      if (parts.length != 2) {
        _error = 'Invalid repo format: ${repoFullNames.first}';
        return;
      }
      _memberStatuses = await _repository.getMembersStatus(parts[0], parts[1]);
    } catch (e) {
      debugPrint('[MemberProvider] Error: $e');
      _error = e.toString();
      _memberStatuses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
