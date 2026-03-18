---
name: sellio-metrics-conventions
description: Development conventions and patterns for sellio_metrics. TypeScript project with mixed commits.
---

# Sellio Metrics Conventions

> Generated from [Sellio-Squad/sellio_metrics](https://github.com/Sellio-Squad/sellio_metrics) on 2026-03-18

## Overview

This skill teaches Claude the development patterns and conventions used in sellio_metrics.

## Tech Stack

- **Primary Language**: TypeScript
- **Architecture**: feature-based module organization
- **Test Location**: separate

## When to Use This Skill

Activate this skill when:
- Making changes to this repository
- Adding new features following established patterns
- Writing tests that match project conventions
- Creating commits with proper message format

## Commit Conventions

Follow these commit message conventions based on 8 analyzed commits.

### Commit Style: Mixed Style

### Prefixes Used

- `feat`
- `refactor`

### Message Guidelines

- Average message length: ~51 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
feat(core): implement line-based scoring & developer event deletion
```

*Commit message example*

```text
refactor(presentation): restructure providers into feature folders (#88)
```

*Commit message example*

```text
ci(frontend): Add build_runner step to deploy workflow (#83)
```

*Commit message example*

```text
chore(config): update MEMBERS_KV namespace ID
```

*Commit message example*

```text
fix(frontend): resolve missing exceptions and dio imports in logs feature (#59)
```

*Commit message example*

```text
Merge main into develop
```

*Commit message example*

```text
refactor(presentation): restructure providers into feature folders
```

*Commit message example*

```text
Develop (#87)
```

## Architecture

### Project Structure: Single Package

This project uses **feature-based** module organization.

### Configuration Files

- `.github/workflows/auto-update.yml`
- `.github/workflows/deploy-backend.yml`
- `.github/workflows/deploy-frontend.yml`
- `backend/package.json`
- `backend/tsconfig.json`
- `backend/wrangler.toml`

### Guidelines

- Group related code by feature/domain
- Each feature folder should be self-contained
- Shared utilities go in a common/shared folder

## Code Style

### Language: TypeScript

### Naming Conventions

| Element | Convention |
|---------|------------|
| Files | snake_case |
| Functions | camelCase |
| Classes | PascalCase |
| Constants | SCREAMING_SNAKE_CASE |

### Import Style: Relative Imports

### Export Style: Named Exports


*Preferred import style*

```typescript
// Use relative imports
import { Button } from '../components/Button'
import { useAuth } from './hooks/useAuth'
```

*Preferred export style*

```typescript
// Use named exports
export function calculateTotal() { ... }
export const TAX_RATE = 0.1
export interface Order { ... }
```

## Error Handling

### Error Handling Style: Try-Catch Blocks

This project uses **custom error classes** for specific error types.


*Standard error handling pattern*

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  console.error('Operation failed:', error)
  throw new Error('User-friendly message')
}
```

## Common Workflows

These workflows were detected from analyzing commit patterns.

### Feature Development

Standard feature implementation workflow

**Frequency**: ~10 times per month

**Steps**:
1. Add feature implementation
2. Add tests for feature
3. Update documentation

**Files typically involved**:
- `backend/src/core/*`
- `backend/src/infra/github/*`
- `backend/src/modules/prs/*`
- `**/*.test.*`
- `**/api/**`

**Example commit sequence**:
```
feat(prs): Add organization-wide open PRs fetching (#71)
refactor(web): Migrate to dart:js_interop and web package
Merge develop into feature/Add-organization-wide-open-PRs-fetching
```

### Refactoring

Code refactoring and cleanup workflow

**Frequency**: ~13 times per month

**Steps**:
1. Ensure tests pass before refactor
2. Refactor code structure
3. Verify tests still pass

**Files typically involved**:
- `src/**/*`

**Example commit sequence**:
```
refactor(prs): streamline open PRs data fetching
Merge develop into feature/Add-organization-wide-open-PRs-fetching
Merge pull request #74 from Sellio-Squad/feature/Add-organization-wide-open-PRs-fetching
```

### Add Or Refactor Feature Page With Widgets

Adds a new feature page or refactors an existing one by splitting logic into multiple smaller widgets/components for improved maintainability and readability.

**Frequency**: ~3 times per month

**Steps**:
1. Create or update main page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
2. Create or update multiple widget/component files in frontend/lib/presentation/pages/<feature>/widgets/
3. Update navigation or routing in frontend/lib/core/navigation/app_navigation.dart if needed
4. Update provider in frontend/lib/presentation/providers/<feature>_provider.dart if needed

**Files typically involved**:
- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`
- `frontend/lib/presentation/pages/<feature>/widgets/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/presentation/providers/<feature>_provider.dart`

**Example commit sequence**:
```
Create or update main page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
Create or update multiple widget/component files in frontend/lib/presentation/pages/<feature>/widgets/
Update navigation or routing in frontend/lib/core/navigation/app_navigation.dart if needed
Update provider in frontend/lib/presentation/providers/<feature>_provider.dart if needed
```

### Refactor Provider Structure Into Feature Folders

Moves ChangeNotifier providers from a flat providers directory into feature-specific folders, updating all imports and usages accordingly.

**Frequency**: ~1 times per month

**Steps**:
1. Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
2. Update all import statements across the codebase to point to the new provider locations
3. Update main app file and navigation if necessary

**Files typically involved**:
- `frontend/lib/presentation/providers/*.dart`
- `frontend/lib/presentation/pages/<feature>/providers/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`

**Example commit sequence**:
```
Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
Update all import statements across the codebase to point to the new provider locations
Update main app file and navigation if necessary
```

### Add Or Refactor Api Endpoint And Consume In Frontend

Introduces a new backend API endpoint or refactors an existing one, then updates the frontend data source, repository, and provider to consume the new endpoint.

**Frequency**: ~2 times per month

**Steps**:
1. Create or update backend service/controller file (e.g., backend/src/modules/<feature>/<feature>.service.ts)
2. Update backend API routing (e.g., backend/src/worker.ts)
3. Update backend dependency injection/container if needed
4. Update frontend data source (frontend/lib/data/datasources/<feature>_data_source.dart)
5. Update frontend repository (frontend/lib/data/repositories/<feature>_repository_impl.dart)
6. Update frontend provider (frontend/lib/presentation/providers/<feature>_provider.dart)
7. Update frontend page or widget to use the new data

**Files typically involved**:
- `backend/src/modules/<feature>/<feature>.service.ts`
- `backend/src/worker.ts`
- `backend/src/core/container.ts`
- `frontend/lib/data/datasources/<feature>_data_source.dart`
- `frontend/lib/data/repositories/<feature>_repository_impl.dart`
- `frontend/lib/presentation/providers/<feature>_provider.dart`
- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`

**Example commit sequence**:
```
Create or update backend service/controller file (e.g., backend/src/modules/<feature>/<feature>.service.ts)
Update backend API routing (e.g., backend/src/worker.ts)
Update backend dependency injection/container if needed
Update frontend data source (frontend/lib/data/datasources/<feature>_data_source.dart)
Update frontend repository (frontend/lib/data/repositories/<feature>_repository_impl.dart)
Update frontend provider (frontend/lib/presentation/providers/<feature>_provider.dart)
Update frontend page or widget to use the new data
```

### Add Or Refactor Member Status Ui

Refactors or enhances the member status display by updating the member card, status indicator, and related widgets, often updating localization and fake data sources.

**Frequency**: ~2 times per month

**Steps**:
1. Update or create new widgets in frontend/lib/presentation/pages/members/widgets/
2. Update members page in frontend/lib/presentation/pages/members/members_page.dart
3. Update localization files (frontend/lib/l10n/app_en.arb, app_ar.arb)
4. Update fake data sources (frontend/lib/data/datasources/fake/fake_datasources.dart)

**Files typically involved**:
- `frontend/lib/presentation/pages/members/widgets/*.dart`
- `frontend/lib/presentation/pages/members/members_page.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/l10n/app_ar.arb`
- `frontend/lib/data/datasources/fake/fake_datasources.dart`

**Example commit sequence**:
```
Update or create new widgets in frontend/lib/presentation/pages/members/widgets/
Update members page in frontend/lib/presentation/pages/members/members_page.dart
Update localization files (frontend/lib/l10n/app_en.arb, app_ar.arb)
Update fake data sources (frontend/lib/data/datasources/fake/fake_datasources.dart)
```

### Backend Leaderboard Or Metrics Rules Change

Adds or refines backend logic for scoring, metrics, or leaderboard rules, often including a database migration and updating aggregation logic.

**Frequency**: ~1 times per month

**Steps**:
1. Create or update migration file (backend/migrations/*.sql)
2. Update backend event types or typescript definitions
3. Update database service or aggregation logic
4. Update API documentation if necessary
5. Update frontend repository/entities if affected

**Files typically involved**:
- `backend/migrations/*.sql`
- `backend/src/core/event-types.ts`
- `backend/src/core/types.ts`
- `backend/src/infra/database/d1.service.ts`
- `backend/src/modules/metrics/*.ts`
- `backend/src/worker.ts`
- `docs/Sellio_Metrics_API.postman_collection.json`
- `frontend/lib/data/repositories/leaderboard_repository_impl.dart`
- `frontend/lib/domain/entities/leaderboard_entry.dart`

**Example commit sequence**:
```
Create or update migration file (backend/migrations/*.sql)
Update backend event types or typescript definitions
Update database service or aggregation logic
Update API documentation if necessary
Update frontend repository/entities if affected
```


## Best Practices

Based on analysis of the codebase, follow these practices:

### Do

- Keep feature code co-located in feature folders
- Use snake_case for file names
- Prefer named exports

### Don't

- Don't deviate from established patterns without discussion

---

*This skill was auto-generated by [ECC Tools](https://ecc.tools). Review and customize as needed for your team.*
