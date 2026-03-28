import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';

@injectable
class FilterProvider extends ChangeNotifier {
  String _weekFilter = FilterOptions.all;
  String _developerFilter = FilterOptions.all;
  String _searchTerm = '';
  String _statusFilter = FilterOptions.all;
  double _bottleneckThreshold = BottleneckConfig.defaultThresholdHours;
  DateTime? _startDate;
  DateTime? _endDate;

  String get weekFilter => _weekFilter;
  String get developerFilter => _developerFilter;
  String get searchTerm => _searchTerm;
  String get statusFilter => _statusFilter;
  double get bottleneckThreshold => _bottleneckThreshold;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  void setWeekFilter(String week) {
    if (_weekFilter != week) {
      _weekFilter = week;
      notifyListeners();
    }
  }

  void setDeveloperFilter(String dev) {
    if (_developerFilter != dev) {
      _developerFilter = dev;
      notifyListeners();
    }
  }

  void setSearchTerm(String term) {
    if (_searchTerm != term) {
      _searchTerm = term;
      notifyListeners();
    }
  }

  void setStatusFilter(String status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      notifyListeners();
    }
  }

  void setBottleneckThreshold(double threshold) {
    if (_bottleneckThreshold != threshold) {
      _bottleneckThreshold = threshold;
      notifyListeners();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    if (_startDate != start || _endDate != end) {
      _startDate = start;
      _endDate = end;
      notifyListeners();
    }
  }
}
