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
feat: add sellio_metrics ECC bundle (.claude/commands/add-or-refactor-feature-page-with-widgets.md)
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

### Feature Development With Page And Widgets

Implements a new feature page or enhances an existing one with supporting widgets, navigation, and data providers.

**Frequency**: ~4 times per month

**Steps**:
1. Create or update a page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
2. Add or update supporting widgets in frontend/lib/presentation/pages/<feature>/widgets/
3. Update or add providers in frontend/lib/presentation/pages/<feature>/providers/
4. Update navigation in frontend/lib/core/navigation/app_navigation.dart
5. Update or create domain/data entities and services as needed
6. Update localization files if UI text changes (frontend/lib/l10n/app_*.arb)

**Files typically involved**:
- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/l10n/app_ar.arb`
- `frontend/lib/l10n/app_en.arb`

**Example commit sequence**:
```
Create or update a page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
Add or update supporting widgets in frontend/lib/presentation/pages/<feature>/widgets/
Update or add providers in frontend/lib/presentation/pages/<feature>/providers/
Update navigation in frontend/lib/core/navigation/app_navigation.dart
Update or create domain/data entities and services as needed
Update localization files if UI text changes (frontend/lib/l10n/app_*.arb)
```

### Refactor Presentation Providers Into Feature Folders

Moves ChangeNotifier providers from a shared directory into feature-specific folders, updating all imports and references.

**Frequency**: ~2 times per month

**Steps**:
1. Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
2. Update all import statements across the codebase to reflect new provider locations
3. Test to ensure all providers are correctly referenced and functionality is intact

**Files typically involved**:
- `frontend/lib/presentation/providers/*.dart`
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/presentation/pages/*/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`

**Example commit sequence**:
```
Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
Update all import statements across the codebase to reflect new provider locations
Test to ensure all providers are correctly referenced and functionality is intact
```

### Enhance Or Refactor Widget Ui

Refactors or enhances UI widgets for improved flexibility, appearance, or maintainability.

**Frequency**: ~3 times per month

**Steps**:
1. Modify widget files in frontend/lib/presentation/widgets/ or frontend/lib/presentation/pages/<feature>/widgets/
2. Update usage of the widget in relevant page files
3. Update or add new properties, assertions, or display logic
4. Update localization files if UI text is affected

**Files typically involved**:
- `frontend/lib/presentation/widgets/*.dart`
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/l10n/app_ar.arb`
- `frontend/lib/l10n/app_en.arb`

**Example commit sequence**:
```
Modify widget files in frontend/lib/presentation/widgets/ or frontend/lib/presentation/pages/<feature>/widgets/
Update usage of the widget in relevant page files
Update or add new properties, assertions, or display logic
Update localization files if UI text is affected
```

### Add Or Refactor Backend Api Or Service

Adds or refactors backend API endpoints or services, including caching, event processing, or metrics logic.

**Frequency**: ~2 times per month

**Steps**:
1. Create or update service files in backend/src/modules/<module>/*.ts
2. Update core types or event processing logic in backend/src/core/ or backend/src/worker.ts
3. Update or add migration or SQL files if database schema changes
4. Update API documentation if needed

**Files typically involved**:
- `backend/src/modules/*/*.ts`
- `backend/src/core/*.ts`
- `backend/src/worker.ts`
- `backend/migrations/*.sql`
- `docs/Sellio_Metrics_API.postman_collection.json`

**Example commit sequence**:
```
Create or update service files in backend/src/modules/<module>/*.ts
Update core types or event processing logic in backend/src/core/ or backend/src/worker.ts
Update or add migration or SQL files if database schema changes
Update API documentation if needed
```

### Add Or Enhance Member Status Ui

Refactors or enhances the members page and related widgets to improve status display and layout.

**Frequency**: ~2 times per month

**Steps**:
1. Update or add widgets in frontend/lib/presentation/pages/members/widgets/
2. Modify members_page.dart and related provider/entity files
3. Update fake data sources for members
4. Update localization files for new/changed status texts

**Files typically involved**:
- `frontend/lib/presentation/pages/members/widgets/*.dart`
- `frontend/lib/presentation/pages/members/members_page.dart`
- `frontend/lib/presentation/providers/member_provider.dart`
- `frontend/lib/data/datasources/fake/fake_datasources.dart`
- `frontend/lib/l10n/app_ar.arb`
- `frontend/lib/l10n/app_en.arb`

**Example commit sequence**:
```
Update or add widgets in frontend/lib/presentation/pages/members/widgets/
Modify members_page.dart and related provider/entity files
Update fake data sources for members
Update localization files for new/changed status texts
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
