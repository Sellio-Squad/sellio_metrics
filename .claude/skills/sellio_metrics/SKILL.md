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

- Average message length: ~55 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/add-or-update-ecc-bundle.md)
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

**Frequency**: ~26 times per month

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
Develop (#87)
refactor(presentation): restructure providers into feature folders
Merge main into develop
```

### Refactoring

Code refactoring and cleanup workflow

**Frequency**: ~5 times per month

**Steps**:
1. Ensure tests pass before refactor
2. Refactor code structure
3. Verify tests still pass

**Files typically involved**:
- `src/**/*`

**Example commit sequence**:
```
Develop (#87)
refactor(presentation): restructure providers into feature folders
Merge main into develop
```

### Ecc Bundle Synchronization

Synchronize or update the ECC bundle for sellio_metrics, including commands, skills, instincts, agent configs, and tool definitions.

**Frequency**: ~3 times per month

**Steps**:
1. Add or update .claude/commands/*.md files for new or changed workflows (e.g., feature-development.md, refactoring.md)
2. Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
3. Add or update .codex/agents/*.toml files (docs-researcher.toml, reviewer.toml, explorer.toml)
4. Add or update .codex/AGENTS.md and .codex/config.toml
5. Add or update .claude/identity.json
6. Add or update .agents/skills/sellio_metrics/agents/openai.yaml
7. Add or update .agents/skills/sellio_metrics/SKILL.md and .claude/skills/sellio_metrics/SKILL.md
8. Add or update .claude/ecc-tools.json

**Files typically involved**:
- `.claude/commands/*.md`
- `.claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml`
- `.codex/agents/*.toml`
- `.codex/AGENTS.md`
- `.codex/config.toml`
- `.claude/identity.json`
- `.agents/skills/sellio_metrics/agents/openai.yaml`
- `.agents/skills/sellio_metrics/SKILL.md`
- `.claude/skills/sellio_metrics/SKILL.md`
- `.claude/ecc-tools.json`

**Example commit sequence**:
```
Add or update .claude/commands/*.md files for new or changed workflows (e.g., feature-development.md, refactoring.md)
Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
Add or update .codex/agents/*.toml files (docs-researcher.toml, reviewer.toml, explorer.toml)
Add or update .codex/AGENTS.md and .codex/config.toml
Add or update .claude/identity.json
Add or update .agents/skills/sellio_metrics/agents/openai.yaml
Add or update .agents/skills/sellio_metrics/SKILL.md and .claude/skills/sellio_metrics/SKILL.md
Add or update .claude/ecc-tools.json
```

### Feature Refactor Provider Restructure

Restructure frontend provider files into feature-specific folders and update all relevant imports for better maintainability.

**Frequency**: ~2 times per month

**Steps**:
1. Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
2. Update all import statements across the frontend to point to the new provider locations
3. Update related page and widget files to use the new provider paths

**Files typically involved**:
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/presentation/pages/*/*.dart`
- `frontend/lib/presentation/widgets/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`

**Example commit sequence**:
```
Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
Update all import statements across the frontend to point to the new provider locations
Update related page and widget files to use the new provider paths
```

### Feature Development With Api And Frontend

Develop a new feature that includes backend (API/database), frontend (UI), and documentation updates.

**Frequency**: ~2 times per month

**Steps**:
1. Create or update backend migration files (e.g., backend/migrations/*.sql)
2. Implement or update backend logic (e.g., backend/src/core/*.ts, backend/src/infra/database/*.ts, backend/src/worker.ts)
3. Add or update API documentation (e.g., docs/Sellio_Metrics_API.postman_collection.json)
4. Implement or update frontend repository, entity, and page files (e.g., frontend/lib/data/repositories/*, frontend/lib/domain/entities/*, frontend/lib/presentation/pages/*)
5. Update frontend localization files if needed (e.g., frontend/lib/l10n/*.arb)
6. Update or create new frontend widgets as required

**Files typically involved**:
- `backend/migrations/*.sql`
- `backend/src/core/*.ts`
- `backend/src/infra/database/*.ts`
- `backend/src/worker.ts`
- `docs/Sellio_Metrics_API.postman_collection.json`
- `frontend/lib/data/repositories/*.dart`
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/presentation/pages/*/*.dart`
- `frontend/lib/l10n/*.arb`
- `frontend/lib/presentation/widgets/*.dart`

**Example commit sequence**:
```
Create or update backend migration files (e.g., backend/migrations/*.sql)
Implement or update backend logic (e.g., backend/src/core/*.ts, backend/src/infra/database/*.ts, backend/src/worker.ts)
Add or update API documentation (e.g., docs/Sellio_Metrics_API.postman_collection.json)
Implement or update frontend repository, entity, and page files (e.g., frontend/lib/data/repositories/*, frontend/lib/domain/entities/*, frontend/lib/presentation/pages/*)
Update frontend localization files if needed (e.g., frontend/lib/l10n/*.arb)
Update or create new frontend widgets as required
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
