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
refactor(presentation): restructure providers into feature folders
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
Develop (#87)
```

*Commit message example*

```text
Merge pull request #86 from Sellio-Squad/feature/Add-PR-details-page-and-analysis-features
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

**Frequency**: ~11 times per month

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
feat(prs): Add organization-wide open PRs fetching
Merge pull request #70 from Sellio-Squad/feature/Add-organization-wide-open-PRs-fetching
Merge main into develop
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

### Add Or Refactor Feature With New Page And Provider

Adds or refactors a frontend feature by creating or updating a page, its provider, and related widgets/components, often including navigation updates and entity changes.

**Frequency**: ~4 times per month

**Steps**:
1. Create or update a page under frontend/lib/presentation/pages/<feature>/<feature>_page.dart
2. Create or update provider under frontend/lib/presentation/pages/<feature>/providers/<feature>_provider.dart or frontend/lib/presentation/providers/<feature>_provider.dart
3. Add or update widgets/components under frontend/lib/presentation/pages/<feature>/widgets/
4. Update navigation in frontend/lib/core/navigation/app_navigation.dart
5. Update or add related entities or services under frontend/lib/domain/entities/ or frontend/lib/domain/services/
6. Update localization files if needed (frontend/lib/l10n/app_*.arb)

**Files typically involved**:
- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/presentation/pages/*/providers/*_provider.dart`
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/domain/services/*.dart`
- `frontend/lib/l10n/app_*.arb`

**Example commit sequence**:
```
Create or update a page under frontend/lib/presentation/pages/<feature>/<feature>_page.dart
Create or update provider under frontend/lib/presentation/pages/<feature>/providers/<feature>_provider.dart or frontend/lib/presentation/providers/<feature>_provider.dart
Add or update widgets/components under frontend/lib/presentation/pages/<feature>/widgets/
Update navigation in frontend/lib/core/navigation/app_navigation.dart
Update or add related entities or services under frontend/lib/domain/entities/ or frontend/lib/domain/services/
Update localization files if needed (frontend/lib/l10n/app_*.arb)
```

### Backend Api Endpoint Or Service Expansion

Adds or expands backend API endpoints or services, often with corresponding frontend data source/repository/provider updates.

**Frequency**: ~2 times per month

**Steps**:
1. Implement or update backend service under backend/src/modules/<feature>/*.ts or backend/src/core/*.ts
2. Update backend/src/worker.ts to register new endpoint or logic
3. Update or add migration or schema file if database is involved (backend/migrations/*.sql)
4. Update frontend data source under frontend/lib/data/datasources/<feature>_data_source.dart
5. Update frontend repository under frontend/lib/data/repositories/<feature>_repository_impl.dart
6. Update frontend provider under frontend/lib/presentation/providers/<feature>_provider.dart
7. Update API documentation (docs/Sellio_Metrics_API.postman_collection.json) if applicable

**Files typically involved**:
- `backend/src/modules/*/*.ts`
- `backend/src/core/*.ts`
- `backend/src/worker.ts`
- `backend/migrations/*.sql`
- `frontend/lib/data/datasources/*_data_source.dart`
- `frontend/lib/data/repositories/*_repository_impl.dart`
- `frontend/lib/presentation/providers/*_provider.dart`
- `docs/Sellio_Metrics_API.postman_collection.json`

**Example commit sequence**:
```
Implement or update backend service under backend/src/modules/<feature>/*.ts or backend/src/core/*.ts
Update backend/src/worker.ts to register new endpoint or logic
Update or add migration or schema file if database is involved (backend/migrations/*.sql)
Update frontend data source under frontend/lib/data/datasources/<feature>_data_source.dart
Update frontend repository under frontend/lib/data/repositories/<feature>_repository_impl.dart
Update frontend provider under frontend/lib/presentation/providers/<feature>_provider.dart
Update API documentation (docs/Sellio_Metrics_API.postman_collection.json) if applicable
```

### Refactor Feature Into Smaller Widgets Or Better Structure

Refactors an existing frontend feature by splitting large files into smaller widgets/components and/or reorganizing files into feature folders for maintainability.

**Frequency**: ~2 times per month

**Steps**:
1. Move or split widgets from a monolithic file into frontend/lib/presentation/pages/<feature>/widgets/*.dart
2. Move providers into frontend/lib/presentation/pages/<feature>/providers/ or similar feature folders
3. Update all relevant imports throughout the codebase to reflect new locations
4. Update main feature page to use the new widgets/components

**Files typically involved**:
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/presentation/providers/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`

**Example commit sequence**:
```
Move or split widgets from a monolithic file into frontend/lib/presentation/pages/<feature>/widgets/*.dart
Move providers into frontend/lib/presentation/pages/<feature>/providers/ or similar feature folders
Update all relevant imports throughout the codebase to reflect new locations
Update main feature page to use the new widgets/components
```

### Dependency Injection Infrastructure Migration

Migrates or refactors the dependency injection system (e.g., switching to injectable, updating service locator patterns) and annotates services/providers accordingly.

**Frequency**: ~1 times per month

**Steps**:
1. Add or update DI-related files (e.g., frontend/lib/core/di/app_module.dart, injection.dart, service_locator.dart)
2. Annotate or refactor services, repositories, and providers with new DI decorators/annotations
3. Update pubspec.yaml to include new DI dependencies
4. Update main.dart and app.dart to initialize DI on startup
5. Update all usages of DI throughout the codebase

**Files typically involved**:
- `frontend/lib/core/di/*.dart`
- `frontend/lib/main.dart`
- `frontend/lib/app.dart`
- `frontend/lib/data/datasources/*.dart`
- `frontend/lib/data/repositories/*.dart`
- `frontend/lib/domain/services/*.dart`
- `frontend/lib/presentation/providers/*.dart`
- `frontend/pubspec.yaml`

**Example commit sequence**:
```
Add or update DI-related files (e.g., frontend/lib/core/di/app_module.dart, injection.dart, service_locator.dart)
Annotate or refactor services, repositories, and providers with new DI decorators/annotations
Update pubspec.yaml to include new DI dependencies
Update main.dart and app.dart to initialize DI on startup
Update all usages of DI throughout the codebase
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
