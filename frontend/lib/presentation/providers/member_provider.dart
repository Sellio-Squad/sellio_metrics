import 'package:flutter/foundation.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/member_status_entity.dart';
import '../../domain/repositories/metrics_repository.dart';

class MemberProvider extends ChangeNotifier {
  final MetricsRepository _repository;

  MemberProvider({required MetricsRepository repository})
    : _repository = repository;

  List<MemberStatusEntity> _memberStatuses = [];
  bool _isLoading = false;

  List<MemberStatusEntity> get memberStatuses => _memberStatuses;
  bool get isLoading => _isLoading;

  Future<void> fetchStatuses(List<PrEntity> sourcePrs) async {
    if (sourcePrs.isEmpty) {
      _memberStatuses = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _memberStatuses = await _repository.getMemberStatuses(sourcePrs);
    } catch (e) {
      debugPrint('Error fetching member statuses: $e');
      _memberStatuses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
