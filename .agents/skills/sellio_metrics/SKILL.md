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

- Average message length: ~53 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/feature-development-with-api-and-frontend.md)
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

**Frequency**: ~22 times per month

**Steps**:
1. Add feature implementation
2. Add tests for feature
3. Update documentation

**Files typically involved**:
- `frontend/lib/design_system/components/*`
- `backend/src/core/*`
- `backend/src/infra/database/*`
- `**/api/**`

**Example commit sequence**:
```
ci(frontend): Add build_runner step to deploy workflow
ci(frontend): Add build_runner step to deploy workflow (#83)
Merge main into develop
```

### Refactoring

Code refactoring and cleanup workflow

**Frequency**: ~7 times per month

**Steps**:
1. Ensure tests pass before refactor
2. Refactor code structure
3. Verify tests still pass

**Files typically involved**:
- `src/**/*`

**Example commit sequence**:
```
feat(openprs): refactor open PRs page and components
refactor(ui): enhance KpiCard with richValue and assertions
Merge main into develop
```

### Add Or Update Ecc Bundle

Adds or updates ECC (Extensible Command/Capability) bundle files for the sellio_metrics project, including commands, skills, agent configs, and documentation.

**Frequency**: ~5 times per month

**Steps**:
1. Add or update files in .claude/commands/, .claude/skills/, .claude/homunculus/instincts/inherited/, .codex/agents/, .codex/, .agents/skills/sellio_metrics/
2. Commit with message referencing 'add sellio_metrics ECC bundle'

**Files typically involved**:
- `.claude/commands/*.md`
- `.claude/skills/sellio_metrics/SKILL.md`
- `.claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml`
- `.codex/agents/*.toml`
- `.codex/AGENTS.md`
- `.codex/config.toml`
- `.claude/identity.json`
- `.claude/ecc-tools.json`
- `.agents/skills/sellio_metrics/SKILL.md`
- `.agents/skills/sellio_metrics/agents/openai.yaml`

**Example commit sequence**:
```
Add or update files in .claude/commands/, .claude/skills/, .claude/homunculus/instincts/inherited/, .codex/agents/, .codex/, .agents/skills/sellio_metrics/
Commit with message referencing 'add sellio_metrics ECC bundle'
```

### Frontend Feature Or Refactor With Multi File Touch

Implements a new frontend feature or performs a major refactor, typically involving multiple files across navigation, data sources, domain entities/services, presentation pages/widgets, and providers.

**Frequency**: ~3 times per month

**Steps**:
1. Create or update navigation and routing files
2. Add or update domain entities, enums, or services
3. Add or update data sources and repositories
4. Create or refactor presentation pages and widgets
5. Update or move providers (ChangeNotifier) to new locations
6. Update localization files if UI changes require new text
7. Update or add tests (not always visible in this log)

**Files typically involved**:
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/domain/services/*.dart`
- `frontend/lib/data/datasources/**/*.dart`
- `frontend/lib/data/repositories/**/*.dart`
- `frontend/lib/presentation/pages/**/*.dart`
- `frontend/lib/presentation/widgets/**/*.dart`
- `frontend/lib/presentation/providers/**/*.dart`
- `frontend/lib/l10n/*.arb`

**Example commit sequence**:
```
Create or update navigation and routing files
Add or update domain entities, enums, or services
Add or update data sources and repositories
Create or refactor presentation pages and widgets
Update or move providers (ChangeNotifier) to new locations
Update localization files if UI changes require new text
Update or add tests (not always visible in this log)
```

### Backend Feature With Migration And Api Update

Implements a backend feature that requires a database migration, updates to backend logic, and corresponding API documentation.

**Frequency**: ~1 times per month

**Steps**:
1. Create or update a migration SQL file in backend/migrations/
2. Update backend logic in src/core/ and src/infra/database/
3. Update worker or service files if needed
4. Update API documentation (e.g., Postman collection)
5. Update frontend repositories/entities if API changes affect the client
6. Update localization files if new units or strings are introduced

**Files typically involved**:
- `backend/migrations/*.sql`
- `backend/src/core/*.ts`
- `backend/src/infra/database/*.ts`
- `backend/src/worker.ts`
- `docs/Sellio_Metrics_API.postman_collection.json`
- `frontend/lib/data/repositories/**/*.dart`
- `frontend/lib/domain/entities/**/*.dart`
- `frontend/lib/l10n/*.arb`

**Example commit sequence**:
```
Create or update a migration SQL file in backend/migrations/
Update backend logic in src/core/ and src/infra/database/
Update worker or service files if needed
Update API documentation (e.g., Postman collection)
Update frontend repositories/entities if API changes affect the client
Update localization files if new units or strings are introduced
```

### Ci Cd Workflow Update

Updates CI/CD workflow files, typically to add new build steps or deployment improvements.

**Frequency**: ~1 times per month

**Steps**:
1. Update .github/workflows/*.yml to add or modify build/deploy steps
2. Commit with a message referencing the workflow and the change

**Files typically involved**:
- `.github/workflows/*.yml`

**Example commit sequence**:
```
Update .github/workflows/*.yml to add or modify build/deploy steps
Commit with a message referencing the workflow and the change
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
