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

- Average message length: ~52 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/add-or-refactor-feature-with-new-page-and-provider.md)
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
Merge develop into ecc-tools/sellio_metrics-1773862451360
```

*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/refactoring.md)
```

*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/feature-development.md)
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

**Frequency**: ~18 times per month

**Steps**:
1. Add feature implementation
2. Add tests for feature
3. Update documentation

**Files typically involved**:
- `backend/src/modules/prs/*`
- `backend/src/*`
- `backend/src/core/*`
- `**/*.test.*`
- `**/api/**`

**Example commit sequence**:
```
refactor(prs): Implement cache for open PRs and invalidate on webhook
Merge main into develop
Develop (#78)
```

### Refactoring

Code refactoring and cleanup workflow

**Frequency**: ~10 times per month

**Steps**:
1. Ensure tests pass before refactor
2. Refactor code structure
3. Verify tests still pass

**Files typically involved**:
- `src/**/*`

**Example commit sequence**:
```
feat(members): refactor and enhance member status display
Merge main into develop
Develop (#81)
```

### Feature Development With Api And Frontend

Implements a new feature that involves both backend (API/database) and frontend (UI) changes, often including new endpoints, data models, and UI pages/components.

**Frequency**: ~3 times per month

**Steps**:
1. Create or update backend logic (e.g., new endpoint, service, or database migration).
2. Update backend types and/or migrations if needed.
3. Update or add frontend data repositories/entities to consume new API or data.
4. Implement new or updated frontend pages/components to display the feature.
5. Update localization files if new UI text is added.
6. Update or add documentation (e.g., Postman collection or docs).

**Files typically involved**:
- `backend/src/**/*.ts`
- `backend/migrations/*.sql`
- `docs/*.json`
- `frontend/lib/data/repositories/**/*.dart`
- `frontend/lib/domain/entities/**/*.dart`
- `frontend/lib/presentation/pages/**/*.dart`
- `frontend/lib/l10n/*.arb`

**Example commit sequence**:
```
Create or update backend logic (e.g., new endpoint, service, or database migration).
Update backend types and/or migrations if needed.
Update or add frontend data repositories/entities to consume new API or data.
Implement new or updated frontend pages/components to display the feature.
Update localization files if new UI text is added.
Update or add documentation (e.g., Postman collection or docs).
```

### Frontend Component Refactor And Restructure

Refactors frontend components/widgets, often splitting large files into smaller ones, moving files into feature folders, and updating imports throughout the codebase.

**Frequency**: ~2 times per month

**Steps**:
1. Move or split widgets/components into new files or directories (often feature-based).
2. Update all relevant imports across the frontend codebase.
3. Adjust related page files to use new structure.
4. Update or refactor providers if their location or usage changes.

**Files typically involved**:
- `frontend/lib/presentation/pages/**/*.dart`
- `frontend/lib/presentation/widgets/**/*.dart`
- `frontend/lib/presentation/providers/**/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`

**Example commit sequence**:
```
Move or split widgets/components into new files or directories (often feature-based).
Update all relevant imports across the frontend codebase.
Adjust related page files to use new structure.
Update or refactor providers if their location or usage changes.
```

### Dependency Injection Migration Or Update

Migrates or updates the dependency injection (DI) system in the frontend, such as switching to a new DI framework or updating DI configuration and annotations.

**Frequency**: ~1 times per month

**Steps**:
1. Add or update DI-related dependencies in pubspec.yaml.
2. Create or update DI configuration files (e.g., app_module.dart, injection.dart).
3. Annotate services, repositories, and providers with DI annotations.
4. Update main.dart and other entry points to use the new DI system.
5. Remove or refactor old DI/service locator code.

**Files typically involved**:
- `frontend/pubspec.yaml`
- `frontend/lib/core/di/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/main.dart`
- `frontend/lib/data/repositories/**/*.dart`
- `frontend/lib/domain/services/**/*.dart`
- `frontend/lib/presentation/providers/**/*.dart`

**Example commit sequence**:
```
Add or update DI-related dependencies in pubspec.yaml.
Create or update DI configuration files (e.g., app_module.dart, injection.dart).
Annotate services, repositories, and providers with DI annotations.
Update main.dart and other entry points to use the new DI system.
Remove or refactor old DI/service locator code.
```

### Ci Workflow Update

Updates continuous integration (CI) workflow files, such as adding new build steps or modifying deployment pipelines.

**Frequency**: ~1 times per month

**Steps**:
1. Edit or add steps in workflow YAML files under .github/workflows.
2. Commit and push changes to trigger new CI runs.

**Files typically involved**:
- `.github/workflows/*.yml`

**Example commit sequence**:
```
Edit or add steps in workflow YAML files under .github/workflows.
Commit and push changes to trigger new CI runs.
```

### Backend Caching Enhancement

Implements or improves caching for backend endpoints, including cache invalidation logic tied to webhooks or data updates.

**Frequency**: ~1 times per month

**Steps**:
1. Add or update cache logic in backend service files.
2. Implement or update cache invalidation logic (e.g., on webhook events).
3. Update worker or background job files if needed.

**Files typically involved**:
- `backend/src/modules/**/*.ts`
- `backend/src/worker.ts`

**Example commit sequence**:
```
Add or update cache logic in backend service files.
Implement or update cache invalidation logic (e.g., on webhook events).
Update worker or background job files if needed.
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
