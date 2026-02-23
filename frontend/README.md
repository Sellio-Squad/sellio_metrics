<div align="center">

# 📊 Sellio Metrics — Frontend

**Flutter Web · Clean Architecture · Provider · Hux Design System**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Hux](https://img.shields.io/badge/Hux_UI-0.25.0-6366F1)](https://pub.dev/packages/hux)
[![Provider](https://img.shields.io/badge/Provider-6.x-4CAF50)](https://pub.dev/packages/provider)

*A beautiful, real-time GitHub PR analytics dashboard for the Sellio Squad.*

</div>

---

## 📦 Tech Stack

| Package | Version | Role |
|---------|---------|------|
| **Flutter** | 3.x | UI framework (web target) |
| **hux** | ^0.25.0 | Sellio UI component library |
| **provider** | ^6.1.2 | State management (ChangeNotifier) |
| **fl_chart** | ^0.70.2 | Line, bar, and pie charts |
| **http** | ^1.3.0 | Backend API calls |
| **url_launcher** | ^6.3.1 | Open PR links in browser |
| **intl** | ^0.20.0 | Date formatting & localization |
| **flutter_localizations** | SDK | Arabic/English support |

---

## 🗂️ Project Structure

```
frontend/
├── pubspec.yaml
├── web/                    ← Flutter web entrypoint (index.html, icons)
│
└── lib/
    ├── main.dart           ← App bootstrap
    ├── app.dart            ← MaterialApp + theme + routing + providers
    │
    ├── core/               ← Framework utilities (no business logic)
    │   ├── constants/
    │   │   ├── layout_constants.dart   ← Icon sizes, border radii
    │   │   └── animation_constants.dart ← Durations, hover scale
    │   ├── extensions/
    │   │   └── theme_extensions.dart   ← context.colors, context.textTheme
    │   ├── theme/
    │   │   ├── app_theme.dart          ← ThemeData factory (dark/light)
    │   │   ├── app_typography.dart     ← TextStyle constants
    │   │   ├── app_spacing.dart        ← Spacing tokens (xs → xxxl)
    │   │   ├── app_radius.dart         ← BorderRadius presets
    │   │   └── sellio_colors.dart      ← Brand colors + chart palette
    │   └── utils/
    │       └── date_utils.dart         ← formatRelativeTime, formatShortDate
    │
    ├── design_system/
    │   └── design_system.dart  ← Barrel — re-exports all Hux + theme tokens
    │
    ├── domain/             ← Business logic (zero Flutter/HTTP dependencies)
    │   ├── entities/
    │   │   ├── pr_entity.dart
    │   │   ├── bottleneck_entity.dart
    │   │   ├── collaboration_entity.dart
    │   │   └── kpi_entity.dart
    │   ├── enums/
    │   │   ├── pr_type.dart            ← Feature / Fix / Refactor / Chore / Other
    │   │   └── pr_status.dart
    │   ├── repositories/
    │   │   └── metrics_repository.dart ← IMetricsRepository (interface)
    │   └── services/
    │       ├── bottleneck_service.dart  ← Slow PR detection
    │       ├── spotlight_service.dart   ← Hot streak, fastest reviewer…
    │       ├── collaboration_service.dart ← Leaderboard computation
    │       └── kpi_service.dart         ← KPI aggregation
    │
    ├── data/               ← Data layer (implements domain interfaces)
    │   ├── models/
    │   │   └── pr_model.dart           ← JSON → PrEntity deserialization
    │   ├── remote/
    │   │   └── metrics_remote_data_source.dart ← HTTP calls to backend
    │   └── repositories/
    │       └── metrics_repository_impl.dart
    │
    ├── di/
    │   └── service_locator.dart        ← GetIt / manual DI setup
    │
    ├── presentation/
    │   ├── providers/
    │   │   ├── dashboard_provider.dart ← Main state: metrics, filters, computed
    │   │   ├── app_settings_provider.dart ← Theme, locale, selected repo
    │   │   └── connectivity_provider.dart
    │   │
    │   ├── pages/
    │   │   ├── dashboard_page.dart     ← Shell: sidebar + page switcher
    │   │   ├── analytics_page.dart     ← Spotlight cards + bottleneck list
    │   │   ├── charts_page.dart        ← PR activity, type, review, code charts
    │   │   ├── open_prs_page.dart      ← Filterable PR list
    │   │   ├── team_page.dart          ← Team structure + leaderboard
    │   │   ├── settings_page.dart      ← Repo selector, theme toggle
    │   │   ├── about_page.dart         ← About Sellio (orchestrator)
    │   │   └── about/                  ← About sub-sections (SRP splits)
    │   │       ├── about_hero.dart
    │   │       ├── about_vision_section.dart
    │   │       ├── about_apps_section.dart
    │   │       ├── about_tech_stack_section.dart
    │   │       ├── about_how_to_join_section.dart
    │   │       ├── about_features_section.dart
    │   │       └── about_section_header.dart
    │   │
    │   ├── widgets/
    │   │   ├── kpi_card.dart           ← Metric summary card with trend
    │   │   ├── pr_list_tile.dart       ← Hoverable, clickable PR entry
    │   │   ├── review_load_card.dart   ← Reviewer workload card
    │   │   ├── spotlight_card.dart     ← Highlight card (hot streak…)
    │   │   ├── bottleneck_item.dart    ← Slow PR item with severity
    │   │   ├── leaderboard_card.dart   ← Ranked team member list
    │   │   ├── team_structure_card.dart
    │   │   ├── navigation/
    │   │   │   └── app_sidebar.dart   ← HuxSidebar integration
    │   │   ├── filters/
    │   │   │   └── date_range_filter.dart
    │   │   └── common/
    │   │       ├── loading_screen.dart
    │   │       └── error_screen.dart
    │   │
    │   └── extensions/
    │       ├── pr_type_presentation.dart   ← PrType → color, label, icon
    │       └── severity_presentation.dart  ← Severity → color, label
    │
    └── l10n/
        ├── app_en.arb                  ← English strings
        └── app_localizations.dart      ← Generated localization class
```

---

## ⚙️ Setup

### Step 1 — Install Flutter

```bash
# Check Flutter is installed
flutter --version

# If not, follow: https://flutter.dev/docs/get-started/install
```

### Step 2 — Get Dependencies

```bash
cd frontend
flutter pub get
```

### Step 3 — Generate Localization Files

```bash
flutter gen-l10n
```

> This generates `lib/core/l10n/app_localizations.dart` from the `.arb` files.  
> Must be run after any change to `app_en.arb`.

### Step 4 — Configure Backend URL

In `lib/data/remote/metrics_remote_data_source.dart`, confirm the backend URL:

```dart
static const String _baseUrl = 'http://localhost:3001';
```

Change to your deployed backend URL for production.

### Step 5 — Run in Chrome

```bash
# Development — Chrome with hot reload
flutter run -d chrome

# Or list available devices
flutter devices
```

### Step 6 — Build for Web

```bash
flutter build web --release
# Output: build/web/ — ready to deploy to Firebase Hosting / Vercel / Nginx
```

---

## 🏗️ Architecture

The frontend follows **clean architecture** with strict layer separation:

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│   (Pages, Widgets, Providers — knows Flutter)           │
└─────────────────────────────────────────────────────────┘
                           │ depends on
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     Domain Layer                         │
│   (Entities, Interfaces, Services — NO dependencies)    │
└─────────────────────────────────────────────────────────┘
                           ▲ depends on
                           │
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                          │
│   (Models, HTTP, Repository Impl — implements domain)   │
└─────────────────────────────────────────────────────────┘
```

### Dependency Rule

```
presentation → domain ← data
```

> **Domain has zero external dependencies** — only `dart:core`.  
> It can be tested without Flutter, HTTP, or any package.

---

## 🎨 Design System

All UI tokens are exported from a single barrel:

```dart
import '../../design_system/design_system.dart';
```

This gives you access to:

### Spacing
```dart
AppSpacing.xs    // 4.0
AppSpacing.sm    // 8.0
AppSpacing.md    // 12.0
AppSpacing.lg    // 16.0
AppSpacing.xl    // 24.0
AppSpacing.xxl   // 32.0
AppSpacing.xxxl  // 48.0
```

### Typography
```dart
AppTypography.displayLg   // 32px w700
AppTypography.displaySm   // 24px w700
AppTypography.title       // 20px w600
AppTypography.subtitle    // 16px w600
AppTypography.body        // 14px w400
AppTypography.caption     // 12px w400
AppTypography.overline    // 11px w500 letter-spaced
```

### Border Radius
```dart
AppRadius.smAll   // 6.0 all corners
AppRadius.mdAll   // 10.0 all corners
AppRadius.lgAll   // 16.0 all corners
AppRadius.xlAll   // 24.0 all corners
```

### Theme Extension (via BuildContext)
```dart
final scheme = context.colors;

scheme.primary       // Brand blue
scheme.secondary     // Brand purple
scheme.surfaceLow    // Card background
scheme.stroke        // Border color
scheme.title         // Primary text
scheme.body          // Body text
scheme.hint          // Placeholder text
scheme.green         // Success / added lines
scheme.red           // Error / removed lines
scheme.onPrimary     // Text on primary color
```

### Hux Components

| Component | Import | Usage |
|-----------|--------|-------|
| `HuxBadge` | `design_system.dart` | Status labels |
| `HuxButton` | `design_system.dart` | Primary, ghost, destructive |
| `HuxAvatar` | `design_system.dart` | User with initials fallback |
| `HuxSidebar` | `design_system.dart` | Navigation rail/drawer |
| `LucideIcons` | `design_system.dart` | Icon set |

---

## 📊 Dashboard Pages

| Page | Route | Description |
|------|-------|-------------|
| **Analytics** | `/` | KPI cards, spotlight highlights, bottleneck PRs |
| **Charts** | `/charts` | PR activity, type distribution, review load, code volume |
| **Open PRs** | `/open-prs` | Live filterable PR list with diff stats |
| **Team** | `/team` | Team structure + leaderboard |
| **Settings** | `/settings` | Repo selector, theme toggle, date range |
| **About** | `/about` | About the Sellio project |

---

## 🌍 Localization

All user-visible strings must go through `AppLocalizations`:

```dart
final l10n = AppLocalizations.of(context);

// Usage:
Text(l10n.sectionPrActivity)
Text(l10n.bottleneckWaiting)
```

**Adding new strings:**

1. Add to `lib/l10n/app_en.arb`:
```json
{
  "myNewString": "English text here"
}
```

2. Run `flutter gen-l10n`

3. Use `l10n.myNewString` in your widget

---

## 🔄 State Management

`DashboardProvider` is the central state hub:

```dart
class DashboardProvider extends ChangeNotifier {
  // Raw data (from API)
  List<PrEntity> _allPrs = [];

  // Computed (from domain services)
  List<BottleneckEntity> get bottlenecks => ...
  List<CollaborationEntity> get leaderboard => ...
  SpotlightMetrics get spotlightMetrics => ...

  // Filtered (by date range + developer)
  List<PrEntity> get weekFilteredPrs => ...

  Future<void> loadMetrics(String owner, String repo) async { ... }
}
```

Widgets rebuild only when they `context.watch<DashboardProvider>()` and the state changes.

---

## 🛠️ Flutter Commands

```bash
# Run on Chrome
flutter run -d chrome

# Hot restart
r  # in terminal while running

# Analyze for issues
flutter analyze

# Format code
dart format lib/

# Generate l10n
flutter gen-l10n

# Build web release
flutter build web --release

# Test
flutter test
```

---

## 📋 Code Conventions

| Convention | Rule |
|------------|------|
| Imports | Always use relative paths within `lib/` |
| Themes | Always use `context.colors` — never hardcode colors |
| Spacing | Always use `AppSpacing.*` — never hardcode `SizedBox(height: 16)` |
| Typography | Always use `AppTypography.*` — never hardcode `TextStyle` |
| Strings | Always use `AppLocalizations.of(context).*` — never hardcode English |
| Widgets | Extract widgets > 60 lines into separate files |
| Files | `snake_case.dart` always |

---

## 📄 License

MIT — part of the [Sellio Metrics](../README.md) monorepo.
