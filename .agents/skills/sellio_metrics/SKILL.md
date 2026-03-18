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
feat: add sellio_metrics ECC bundle (.claude/commands/refactoring.md)
```

*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/feature-development.md)
```

*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.codex/agents/docs-researcher.toml)
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

**Frequency**: ~11 times per month

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

### Add Or Refactor Feature With New Page And Provider

Implements a new feature or refactors an existing one by adding a new page (often under open_prs, members, or observability), updating navigation, and creating or updating a provider for state management.

**Frequency**: ~4 times per month

**Steps**:
1. Create or update a new page widget under frontend/lib/presentation/pages/<feature>/
2. Add or update provider under frontend/lib/presentation/providers/ or frontend/lib/presentation/pages/<feature>/providers/
3. Update navigation in frontend/lib/core/navigation/app_navigation.dart
4. Update or create new domain/entity/service files if needed
5. Update or add widgets under frontend/lib/presentation/pages/<feature>/widgets/
6. Update localization files if new UI text is introduced
7. Update or add fake data sources if needed

**Files typically involved**:
- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`
- `frontend/lib/presentation/pages/<feature>/widgets/*.dart`
- `frontend/lib/presentation/providers/<feature>_provider.dart`
- `frontend/lib/presentation/pages/<feature>/providers/<feature>_provider.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/domain/services/*.dart`
- `frontend/lib/data/datasources/fake/fake_datasources.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/l10n/app_ar.arb`

**Example commit sequence**:
```
Create or update a new page widget under frontend/lib/presentation/pages/<feature>/
Add or update provider under frontend/lib/presentation/providers/ or frontend/lib/presentation/pages/<feature>/providers/
Update navigation in frontend/lib/core/navigation/app_navigation.dart
Update or create new domain/entity/service files if needed
Update or add widgets under frontend/lib/presentation/pages/<feature>/widgets/
Update localization files if new UI text is introduced
Update or add fake data sources if needed
```

### Refactor Widget Or Component Into Smaller Widgets

Refactors a large widget/page into smaller, reusable widgets/components for maintainability and readability.

**Frequency**: ~2 times per month

**Steps**:
1. Identify large widget/page (e.g., OpenPrsPage, MemberCard)
2. Extract sections into new widgets under widgets/ subdirectory
3. Update the main page to use the new widgets
4. Update imports and references throughout the codebase

**Files typically involved**:
- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`
- `frontend/lib/presentation/pages/<feature>/widgets/*.dart`

**Example commit sequence**:
```
Identify large widget/page (e.g., OpenPrsPage, MemberCard)
Extract sections into new widgets under widgets/ subdirectory
Update the main page to use the new widgets
Update imports and references throughout the codebase
```

### Backend Api Or Metrics Enhancement

Enhances backend metrics or API logic, often involving changes to event types, database migrations, and updating aggregation logic.

**Frequency**: ~2 times per month

**Steps**:
1. Add or update SQL migration under backend/migrations/
2. Update backend/src/core/event-types.ts or types.ts
3. Update backend/src/infra/database/*.ts or modules/metrics/*.ts
4. Update backend/src/worker.ts for ingestion/processing logic
5. Update API documentation (e.g., Postman collection)
6. Update frontend repository/entities if new data is exposed

**Files typically involved**:
- `backend/migrations/*.sql`
- `backend/src/core/event-types.ts`
- `backend/src/core/types.ts`
- `backend/src/infra/database/*.ts`
- `backend/src/modules/metrics/*.ts`
- `backend/src/worker.ts`
- `docs/Sellio_Metrics_API.postman_collection.json`
- `frontend/lib/data/repositories/*.dart`
- `frontend/lib/domain/entities/*.dart`

**Example commit sequence**:
```
Add or update SQL migration under backend/migrations/
Update backend/src/core/event-types.ts or types.ts
Update backend/src/infra/database/*.ts or modules/metrics/*.ts
Update backend/src/worker.ts for ingestion/processing logic
Update API documentation (e.g., Postman collection)
Update frontend repository/entities if new data is exposed
```

### Dependency Injection Refactor With Injectable

Migrates or refactors dependency injection setup to use the injectable package, updating DI configuration, annotations, and generated files.

**Frequency**: ~1 times per month

**Steps**:
1. Add or update injectable annotations to services, repositories, and providers
2. Create or update DI modules (e.g., app_module.dart)
3. Update or create injection config (e.g., injection.dart, injection.config.dart)
4. Update main.dart to initialize DI
5. Update pubspec.yaml with required dependencies
6. Regenerate DI files (build_runner)

**Files typically involved**:
- `frontend/lib/core/di/app_module.dart`
- `frontend/lib/core/di/injection.dart`
- `frontend/lib/core/di/service_locator.dart`
- `frontend/lib/main.dart`
- `frontend/pubspec.yaml`

**Example commit sequence**:
```
Add or update injectable annotations to services, repositories, and providers
Create or update DI modules (e.g., app_module.dart)
Update or create injection config (e.g., injection.dart, injection.config.dart)
Update main.dart to initialize DI
Update pubspec.yaml with required dependencies
Regenerate DI files (build_runner)
```

### Ci Workflow Update For Build Runner

Updates CI/CD workflow to include build_runner steps for code generation before deployment.

**Frequency**: ~1 times per month

**Steps**:
1. Edit .github/workflows/deploy-frontend.yml
2. Add or update step to run 'dart run build_runner build --delete-conflicting-outputs'
3. Commit and push workflow changes

**Files typically involved**:
- `.github/workflows/deploy-frontend.yml`

**Example commit sequence**:
```
Edit .github/workflows/deploy-frontend.yml
Add or update step to run 'dart run build_runner build --delete-conflicting-outputs'
Commit and push workflow changes
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
