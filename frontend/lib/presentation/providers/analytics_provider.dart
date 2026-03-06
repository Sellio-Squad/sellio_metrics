import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/kpi_entity.dart';
import '../../domain/entities/bottleneck_entity.dart';
import '../../domain/services/kpi_service.dart';
import '../../domain/services/bottleneck_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final KpiService _kpiService;
  final BottleneckService _bottleneckService;

  AnalyticsProvider({
    required KpiService kpiService,
    required BottleneckService bottleneckService,
  })  : _kpiService = kpiService,
        _bottleneckService = bottleneckService;

  KpiEntity calculateKpis(List<PrEntity> sourcePrs, {String? developerFilter}) {
    return _kpiService.calculateKpis(
      sourcePrs,
      developerFilter: developerFilter ?? FilterOptions.all,
    );
  }

  SpotlightEntity calculateSpotlightMetrics(List<PrEntity> sourcePrs, {String? developerFilter}) {
    return _kpiService.calculateSpotlightMetrics(
      sourcePrs,
      developerFilter: developerFilter ?? FilterOptions.all,
    );
  }

  List<BottleneckEntity> identifyBottlenecks(List<PrEntity> sourcePrs, {required double thresholdHours}) {
    return _bottleneckService.identifyBottlenecks(
      sourcePrs,
      thresholdHours: thresholdHours,
    );
  }
}
