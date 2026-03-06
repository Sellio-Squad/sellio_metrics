library;

import '../../core/constants/app_constants.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/datasources/fake_metrics_data_source.dart';
import '../../data/repositories/metrics_repository_impl.dart';
import '../../domain/repositories/metrics_repository.dart';
import '../../domain/services/kpi_service.dart';
import '../../domain/services/bottleneck_service.dart';
import '../../domain/services/filter_service.dart';
import '../../presentation/providers/app_settings_provider.dart';
import '../../presentation/providers/pr_data_provider.dart';
import '../../presentation/providers/filter_provider.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../presentation/providers/leaderboard_provider.dart';
import '../../presentation/providers/member_provider.dart';

/// Global service locator instance.
final sl = ServiceLocator();

/// Simple service locator / DI container.
class ServiceLocator {
  final Map<Type, Object> _instances = {};
  final Map<Type, Object Function()> _factories = {};

  /// Register a singleton instance.
  void registerSingleton<T extends Object>(T instance) {
    _instances[T] = instance;
  }

  /// Register a lazy singleton (created on first access).
  void registerLazySingleton<T extends Object>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Register a factory (creates a new instance each time).
  void registerFactory<T extends Object>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Get an instance of type T.
  T get<T extends Object>() {
    if (_instances.containsKey(T)) return _instances[T] as T;
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      // Cache lazy singletons
      _instances[T] = instance;
      return instance;
    }
    throw StateError('No registration for type $T');
  }

  /// Reset all registrations (useful for testing).
  void reset() {
    _instances.clear();
    _factories.clear();
  }
}

/// Initialize all dependencies.
void setupDependencies() {
  // Data sources — switchable between remote backend and local fake data.
  if (ApiConfig.useFakeData) {
    sl.registerSingleton<MetricsDataSource>(
      FakeMetricsDataSource(),
    );
  } else {
    sl.registerSingleton<MetricsDataSource>(
      RemoteDataSource(baseUrl: ApiConfig.baseUrl),
    );
  }

  // Repository
  sl.registerLazySingleton<MetricsRepository>(
    () => MetricsRepositoryImpl(dataSource: sl.get<MetricsDataSource>()),
  );

  // Domain services
  sl.registerSingleton<KpiService>(const KpiService());
  sl.registerSingleton<BottleneckService>(const BottleneckService());
  sl.registerSingleton<FilterService>(const FilterService());

  // Providers
  sl.registerFactory<AppSettingsProvider>(
    () => AppSettingsProvider(repository: sl.get<MetricsRepository>()),
  );
  sl.registerFactory<PrDataProvider>(
    () => PrDataProvider(repository: sl.get<MetricsRepository>()),
  );
  sl.registerFactory<FilterProvider>(
    () => FilterProvider(),
  );
  sl.registerFactory<AnalyticsProvider>(
    () => AnalyticsProvider(
      kpiService: sl.get<KpiService>(),
      bottleneckService: sl.get<BottleneckService>(),
    ),
  );
  sl.registerFactory<LeaderboardProvider>(
    () => LeaderboardProvider(repository: sl.get<MetricsRepository>()),
  );
  sl.registerFactory<MemberProvider>(
    () => MemberProvider(repository: sl.get<MetricsRepository>()),
  );
}

