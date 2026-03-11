/// Sellio Metrics — Service Locator (DI Container)
///
/// Registers dependencies following Clean Architecture:
///   - Datasource interfaces → remote or fake implementations
///   - Repository interfaces → implementation classes (depend on datasource interfaces)
///   - Providers              → depend on repository INTERFACES (DIP)
///
/// No provider depends on a concrete class. All wiring is here only.
library;

import '../../core/constants/app_constants.dart';
import '../../data/datasources/fake/fake_meetings_data_source.dart';
import '../logging/app_logger.dart';

// ── Datasource Interfaces & Impls ────────────────────────────
import '../../data/datasources/repos_data_source.dart';
import '../../data/datasources/leaderboard_data_source.dart';
import '../../data/datasources/members_data_source.dart';
import '../../data/datasources/fake/fake_datasources.dart';
import '../../data/datasources/pr_data_source.dart';
import '../../data/datasources/health_data_source.dart';
import '../../data/datasources/logs_data_source.dart';

// ── Repository Interfaces & Impls ────────────────────────────
import '../../domain/repositories/repos_repository.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/repositories/members_repository.dart';
import '../../domain/repositories/pr_repository.dart';
import '../../domain/repositories/health_repository.dart';
import '../../data/repositories/repos_repository_impl.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../data/repositories/members_repository_impl.dart';
import '../../data/repositories/pr_repository_impl.dart';
import '../../data/repositories/health_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

// ── Domain Services ──────────────────────────────────────────
import '../../domain/services/kpi_service.dart';
import '../../domain/services/bottleneck_service.dart';
import '../../domain/services/filter_service.dart';

// ── Providers ────────────────────────────────────────────────
import '../../presentation/providers/app_settings_provider.dart';
import '../../presentation/providers/filter_provider.dart';
import '../../presentation/providers/leaderboard_provider.dart';
import '../../presentation/providers/member_provider.dart';
import '../../presentation/providers/pr_data_provider.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../presentation/providers/health_status_provider.dart';
import '../../presentation/providers/logs_provider.dart';

// ── Meetings Feature ─────────────────────────────────────────
import '../../data/datasources/meetings_data_source.dart';
import '../../data/repositories/meetings_repository_impl.dart';
import '../../domain/repositories/meetings_repository.dart';
import '../../presentation/providers/meetings_provider.dart';

// ── Meet Events Feature ───────────────────────────────────────
import '../../data/datasources/meet_events_data_source.dart';
import '../../data/repositories/meet_events_repository_impl.dart';
import '../../domain/repositories/meet_events_repository.dart';
import '../../presentation/providers/meet_events_provider.dart';

// ─────────────────────────────────────────────────────────────

/// Global service locator instance.
final sl = ServiceLocator();

/// Minimal service locator / DI container.
class ServiceLocator {
  final Map<Type, Object> _singletons = {};
  final Map<Type, Object Function()> _factories = {};

  void registerSingleton<T extends Object>(T instance) {
    _singletons[T] = instance;
  }

  void registerLazySingleton<T extends Object>(T Function() factory) {
    _factories[T] = factory;
  }

  void registerFactory<T extends Object>(T Function() factory) {
    _factories[T] = factory;
  }

  T get<T extends Object>() {
    if (_singletons.containsKey(T)) return _singletons[T] as T;
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _singletons[T] = instance; // cache as singleton after first creation
      return instance;
    }
    throw StateError('No registration for type $T');
  }

  void reset() {
    _singletons.clear();
    _factories.clear();
  }
}

/// Wire up all dependencies.
void setupDependencies() {
  final useFake = ApiConfig.useFakeData;
  final baseUrl = ApiConfig.baseUrl;

  // ── Core Utilities ──────────────────────────────────────────
  sl.registerSingleton<AppLogger>(ConsoleAppLogger());

  // ── Datasources (interface ← impl) ────────────────────────
  if (useFake) {
    sl.registerSingleton<ReposDataSource>(FakeReposDataSource());
    sl.registerSingleton<LeaderboardDataSource>(FakeLeaderboardDataSource());
    sl.registerSingleton<MembersDataSource>(FakeMembersDataSource());
    sl.registerSingleton<MeetingsDataSource>(FakeMeetingsDataSource());
    sl.registerSingleton<PrDataSource>(FakePrDataSource());
    // Health data source - can add Fake if needed, but for now remote is fine or dummy
    sl.registerSingleton<HealthDataSource>(RemoteHealthDataSource(baseUrl: baseUrl));
    sl.registerSingleton<LogsDataSource>(LogsDataSource(dio: Dio(BaseOptions(baseUrl: baseUrl))));
  } else {
    final client = http.Client();
    sl.registerSingleton<ReposDataSource>(
      RemoteReposDataSource(baseUrl: baseUrl),
    );
    sl.registerSingleton<LeaderboardDataSource>(
      RemoteLeaderboardDataSource(baseUrl: baseUrl),
    );
    sl.registerSingleton<MembersDataSource>(
      RemoteMembersDataSource(baseUrl: baseUrl),
    );
    sl.registerSingleton<MeetingsDataSource>(
      RemoteMeetingsDataSource(baseUrl: baseUrl),
    );
    sl.registerSingleton<PrDataSource>(
      RemotePrDataSource(client: client),
    );
    sl.registerSingleton<HealthDataSource>(
      RemoteHealthDataSource(baseUrl: baseUrl, client: client),
    );
    sl.registerSingleton<LogsDataSource>(
      LogsDataSource(dio: Dio(BaseOptions(baseUrl: baseUrl))),
    );
  }
  // Meet Events is always remote
  sl.registerSingleton<MeetEventsDataSource>(
    RemoteMeetEventsDataSource(baseUrl: baseUrl),
  );

  // ── Repositories (interface ← impl, depends on datasource interface) ──
  sl.registerLazySingleton<ReposRepository>(
    () => ReposRepositoryImpl(dataSource: sl.get<ReposDataSource>()),
  );
  sl.registerLazySingleton<LeaderboardRepository>(
    () => LeaderboardRepositoryImpl(dataSource: sl.get<LeaderboardDataSource>()),
  );
  sl.registerLazySingleton<MembersRepository>(
    () => MembersRepositoryImpl(dataSource: sl.get<MembersDataSource>()),
  );
  sl.registerLazySingleton<PrRepository>(
    () => PrRepositoryImpl(remoteDataSource: sl.get<PrDataSource>()),
  );
  sl.registerLazySingleton<MeetingsRepository>(
    () => MeetingsRepositoryImpl(dataSource: sl.get<MeetingsDataSource>()),
  );
  sl.registerLazySingleton<MeetEventsRepository>(
    () => MeetEventsRepositoryImpl(dataSource: sl.get<MeetEventsDataSource>()),
  );
  sl.registerLazySingleton<HealthRepository>(
    () => HealthRepositoryImpl(dataSource: sl.get<HealthDataSource>()),
  );

  // ── Domain Services ────────────────────────────────────────
  sl.registerSingleton<KpiService>(const KpiService());
  sl.registerSingleton<BottleneckService>(const BottleneckService());
  sl.registerSingleton<FilterService>(const FilterService());

  // ── Providers (depend on repository INTERFACES only) ───────
  sl.registerFactory<AppSettingsProvider>(
    () => AppSettingsProvider(repository: sl.get<ReposRepository>()),
  );
  sl.registerFactory<FilterProvider>(() => FilterProvider());
  sl.registerFactory<LeaderboardProvider>(
    () => LeaderboardProvider(repository: sl.get<LeaderboardRepository>()),
  );
  sl.registerFactory<MemberProvider>(
    () => MemberProvider(repository: sl.get<MembersRepository>()),
  );
  sl.registerFactory<PrDataProvider>(
    () => PrDataProvider(repository: sl.get<PrRepository>()),
  );
  sl.registerFactory<AnalyticsProvider>(() => AnalyticsProvider(
    kpiService: sl.get<KpiService>(),
    bottleneckService: sl.get<BottleneckService>(),
  ));
  sl.registerFactory<MeetingsProvider>(
    () => MeetingsProvider(repository: sl.get<MeetingsRepository>()),
  );
  sl.registerFactory<MeetEventsProvider>(
    () => MeetEventsProvider(repository: sl.get<MeetEventsRepository>()),
  );
  sl.registerFactory<HealthStatusProvider>(
    () => HealthStatusProvider(repository: sl.get<HealthRepository>()),
  );
  sl.registerFactory<LogsProvider>(
    () => LogsProvider(dataSource: sl.get<LogsDataSource>()),
  );
}
