## 🎨 Frontend Architecture (Flutter Web)

The frontend is a **Flutter Web** single‑page application that consumes the backend API and renders a rich dashboard for PR analytics. It follows a Clean Architecture split into:

- **Presentation layer** (`lib/presentation`, `lib/app.dart`, `lib/main.dart`)
- **Domain layer** (`lib/domain`)
- **Data layer** (`lib/data`)
- **Core + Design system** (`lib/core`, `lib/design_system`)
- **Simple DI container** (`lib/core/di/service_locator.dart`)

### 1. Bootstrapping & App Shell

- `main.dart`
  - Entry point that initializes Flutter and calls `runApp(const SellioMetricsApp())`.
- `app.dart`
  - Declares `SellioMetricsApp`:
    - Calls `setupDependencies()` from `core/di/service_locator.dart`.
    - Wraps the app in a `MultiProvider`:
      - `AppSettingsProvider` (theme, locale, repo selection).
      - `DashboardProvider` (metrics state and computed analytics).
    - Configures `MaterialApp`:
      - `theme` / `darkTheme` from `SellioThemes`.
      - `locale` and `supportedLocales` from `AppLocalizations`.
      - Localization delegates for Flutter + custom l10n.
      - Root widget is `_AppEntryPoint`.
- `_AppEntryPoint`
  - On first frame:
    - Loads repositories via `AppSettingsProvider.loadRepositories()`.
    - If repos are available, calls `DashboardProvider.loadData(repos: selectedRepos)`.
  - Shows:
    - `LoadingScreen` while loading.
    - `ErrorScreen` on failure (with retry).
    - `DashboardPage` when data is ready.

### 2. Core & Design System

- `core/constants`, `core/theme`, `core/utils`, `core/extensions`
  - Framework utilities and design tokens:
    - Spacing, radius, typography (`AppSpacing`, `AppRadius`, `AppTypography`).
    - Color palette + theme configuration (`SellioThemes`, `SellioColors`).
    - Date/text helpers (`date_utils.dart`, `formatters.dart`).
    - `theme_extensions.dart` which adds `context.colors` and related helpers.
- `design_system/design_system.dart`
  - Barrel file that re‑exports:
    - Hux UI components (`HuxButton`, `HuxBadge`, `HuxSidebar`, etc.).
    - Design tokens (spacing, type, radius).
    - Custom components such as `SCard`, `SButton`, `SAvatar`, `SDatePicker`.

### 3. Domain Layer (`lib/domain`)

The domain layer holds **pure Dart** code with no Flutter or HTTP dependencies.

- **Entities** (`domain/entities`)
  - `PrEntity`: frontend representation of a PR metric, mirroring backend `PrMetric` while using rich Dart types:
    - Fields for PR metadata (title, refs, creator, assignees, labels, milestone, draft).
    - Timing fields: `openedAt`, `firstApprovedAt`, `timeToFirstApprovalMinutes`, `timeToRequiredApprovalsMinutes`, `closedAt`, `mergedAt`.
    - Derived helpers:
      - `isOpen`, `isMerged`.
      - `repoName` extracted from the PR URL.
      - `timeline` extension: yields a sorted list of `PrTimelineEvent` (created, commented, approved, merged, closed).
      - `participants`: unique set of all involved users (creator, assignees, reviewers, commenters, merger).
  - `BottleneckEntity`, `KpiEntity`, `LeaderboardEntry`, `UserEntity`, `DiffStatsEntity`, `ApprovalEntity`, etc.
- **Enums** (`domain/enums`)
  - `Severity`, `PrType`, and other small classification enums.
- **Repositories** (`domain/repositories`)
  - `MetricsRepository` interface:
    - Defines the contract the presentation layer uses:
      - `Future<List<PrEntity>> getPullRequests(owner, repo)`
      - `Future<List<PrEntity>> refresh(owner, repo)`
      - `Future<List<RepoInfo>> getRepos()`
      - `Future<List<LeaderboardEntry>> calculateLeaderboard(List<PrEntity>)`
- **Services** (`domain/services`)
  - `KpiService`:
    - Aggregates KPIs from a set of `PrEntity` (e.g., average time to merge, PR volume by week, approval rates).
    - Computes spotlight metrics such as hot streaks and fastest reviewers.
  - `BottleneckService`:
    - Identifies long‑waiting PRs:
      - Filters open PRs.
      - Computes wait time in hours/days from `openedAt` to now.
      - Classifies severity using `BottleneckConfig` thresholds.
    - Returns a sorted `List<BottleneckEntity>` (longest wait first, capped by max display count).
  - `FilterService`:
    - Encapsulates filtering logic:
      - By date range.
      - By week bucket.
      - By status, search term, or developer filter.

### 4. Data Layer (`lib/data`)

The data layer implements domain repository interfaces and handles HTTP + JSON.

- **Models** (`data/models/pr_model.dart`)
  - DTO that maps backend `PrMetric` JSON into `PrEntity`:
    - Parses ISO date strings into `DateTime`.
    - Converts nested structures (creator, assignees, comments, approvals, diff stats).
    - Bridges any naming differences between backend and frontend entities.
- **Remote data source** (`data/datasources/remote_data_source.dart`)
  - Performs HTTP calls using the `http` package:
    - Reads `ApiConfig.baseUrl` (and `USE_FAKE_DATA` flag) from `core/constants/app_constants.dart` or Dart defines.
    - Exposes methods like `getPullRequests(owner, repo)` and underlying low‑level HTTP helpers.
- **Local/fake data sources**
  - `data/datasources/local_data_source.dart` / `fake_metrics_data_source.dart`:
    - Provide in‑memory or fixture‑based PR data (useful for demos/dev without a backend).
- **Repository implementation** (`data/repositories/metrics_repository_impl.dart`)
  - Implements `MetricsRepository`:
    - Chooses between remote or fake data sources based on config.
    - Maps raw JSON/DTOs into `PrEntity`.
    - Delegates leaderboard computation to the backend endpoint when available, or computes client‑side as needed.

### 5. Dependency Injection (`core/di/service_locator.dart`)

The frontend uses a small custom service locator rather than a heavy DI framework:

- `ServiceLocator`:
  - Maintains maps of singletons and factories by type.
  - Supports:
    - `registerSingleton<T>(T instance)`
    - `registerLazySingleton<T>(() => T)`
    - `registerFactory<T>(() => T)`
    - `get<T>()` to resolve dependencies.
- `setupDependencies()`:
  - Registers data sources:
    - If `ApiConfig.useFakeData` is `true`, registers `FakeMetricsDataSource`.
    - Else registers `RemoteDataSource(baseUrl: ApiConfig.baseUrl)`.
  - Registers:
    - `MetricsRepositoryImpl` as `MetricsRepository` (lazy singleton).
    - Domain services: `KpiService`, `BottleneckService`, `FilterService`.
    - Providers:
      - `AppSettingsProvider(repository: sl.get<MetricsRepository>())`.
      - `DashboardProvider(repository, kpiService, bottleneckService, filterService)`.

This DI layer is intentionally simple and test‑friendly.

### 6. Presentation Layer (`lib/presentation`)

#### 6.1 Providers

- `DashboardProvider`:
  - Holds the **canonical PR dataset** for the UI:
    - `_allPrs`: all loaded `PrEntity` objects.
    - `_currentRepos`: list of `RepoInfo` currently selected.
    - Various filters: week, developer, status, search term, date range, bottleneck threshold.
  - Exposes computed views:
    - `weekFilteredPrs` → PRs filtered by date range + week.
    - `filteredPrs` → further filtered by search and status.
    - `openPrs` → open PRs only.
  - Exposes analytics derived from domain services:
    - `kpis` → overall KPIs (`KpiEntity`).
    - `spotlightMetrics` → spotlight KPIs.
    - `bottlenecks` → bottleneck PRs from `BottleneckService.identifyBottlenecks`.
    - `leaderboard` → `List<LeaderboardEntry>`, updated via `_repository.calculateLeaderboard`.
  - Main actions:
    - `ensureDataLoaded(repos)` to avoid redundant loading.
    - `loadData(repos: ...)` to fetch and aggregate PRs across multiple repos.
    - `refresh()` to force re‑fetch from the backend.
    - `setSearchTerm`, `setDateRange`, and other filter setters that recompute derived data and notify listeners.
- `AppSettingsProvider`:
  - Persists and exposes user preferences:
    - Selected repositories.
    - Theme mode (light/dark).
    - Locale (e.g., English/Arabic).

#### 6.2 Pages & Navigation

- Navigation is organized through:
  - `presentation/navigation/app_sidebar.dart` and `app_bottom_nav.dart` for desktop vs. mobile layouts.
- Key pages:
  - `dashboard_page.dart`: main shell; composes sections for analytics, charts, open PRs, leaderboard, settings, and about.
  - `charts_page.dart`: visualizations for:
    - PR activity over time.
    - PR type distribution.
    - Review load and code volume.
  - `open_prs_page.dart`: filterable list of open PRs using `PrListTile`.
  - `leaderboard_page.dart` + `leaderboard_section.dart`: team leaderboard view.
  - `settings_page.dart`:
    - Repo selector, theme toggle, language toggle.
    - `github_rate_limit_banner.dart` shows rate‑limit status hints.
  - `about_page.dart` and its sections:
    - `about_hero`, `about_vision_section`, `about_apps_section`, `about_tech_stack_section`, `about_how_to_join_section`, `about_features_section`.

#### 6.3 Widgets & Extensions

- Core widgets:
  - `kpi_card.dart`: shows a KPI value with trend/subtext.
  - `spotlight_card.dart`: highlights hot streaks or outliers.
  - `bottleneck_item.dart`: renders bottleneck PRs with severity highlights.
  - `pr_list_tile.dart`: interactive list entry for a PR (hover, click, open in GitHub).
  - `leaderboard_row.dart` / `leaderboard_card.dart`: show individual/team metrics.
  - Date filters: `date_range_filter.dart`, `date_range_chip.dart`.
  - Common screens: `loading_screen.dart`, `error_screen.dart`.
- Extensions:
  - `pr_type_presentation.dart`:
    - Maps domain `PrType` to display label, color, and icon.
  - `severity_presentation.dart`:
    - Maps `Severity` to color/label for bottlenecks.

### 7. Clean Architecture Rules in Practice

- **Presentation** depends on **Domain** and **Repository interfaces**, but not on HTTP or persistence details.
- **Domain** depends on nothing but `dart:core`.
- **Data** depends on both **Domain** (to implement repository interfaces and construct entities) and external packages (`http`, etc.).
- Dependency arrows follow:

```text
presentation → domain ← data
```

This makes most of the core logic (entities + services) easily testable in isolation and keeps visual components thin and declarative. For a diagram‑driven view of these dependencies, see `ARCHITECTURE.md` (sections 4 and 5). 

