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

- Average message length: ~54 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
feat: add sellio_metrics ECC bundle (.claude/commands/feature-development-with-page-and-widgets.md)
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

### Ecc Bundle Onboarding

Adds a new ECC bundle for sellio_metrics, including commands, skills, agents, and configuration files for Claude and Codex ecosystems.

**Frequency**: ~2 times per month

**Steps**:
1. Add or update .claude/commands/*.md files (feature-development, refactoring, etc.)
2. Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
3. Add or update .codex/agents/*.toml files (docs-researcher, reviewer, explorer)
4. Add or update .codex/AGENTS.md and .codex/config.toml
5. Add or update .claude/identity.json
6. Add or update .agents/skills/sellio_metrics/agents/openai.yaml
7. Add or update .agents/skills/sellio_metrics/SKILL.md
8. Add or update .claude/skills/sellio_metrics/SKILL.md
9. Add or update .claude/ecc-tools.json

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
Add or update .claude/commands/*.md files (feature-development, refactoring, etc.)
Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
Add or update .codex/agents/*.toml files (docs-researcher, reviewer, explorer)
Add or update .codex/AGENTS.md and .codex/config.toml
Add or update .claude/identity.json
Add or update .agents/skills/sellio_metrics/agents/openai.yaml
Add or update .agents/skills/sellio_metrics/SKILL.md
Add or update .claude/skills/sellio_metrics/SKILL.md
Add or update .claude/ecc-tools.json
```

### Feature Development Pr Details Page

Implements a new feature (PR details page and analysis) by adding new entities, services, widgets, and updating navigation and presentation files.

**Frequency**: ~2 times per month

**Steps**:
1. Add new domain entities and enums (e.g., pr_code_insight.dart, pr_entity.dart, pr_size_category.dart)
2. Add or update domain services (e.g., pr_analysis_service.dart)
3. Add new presentation pages and widgets (e.g., pr_details_page.dart, pr_code_insights_section.dart, pr_media_section.dart, pr_ticket_link_section.dart)
4. Update navigation to include new routes (app_navigation.dart)
5. Update or refactor existing widgets and list tiles to integrate the new feature
6. Update data sources and providers as needed

**Files typically involved**:
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/domain/enums/*.dart`
- `frontend/lib/domain/services/*.dart`
- `frontend/lib/presentation/pages/open_prs/pr_details_page.dart`
- `frontend/lib/presentation/pages/open_prs/widgets/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/presentation/providers/pr_data_provider.dart`

**Example commit sequence**:
```
Add new domain entities and enums (e.g., pr_code_insight.dart, pr_entity.dart, pr_size_category.dart)
Add or update domain services (e.g., pr_analysis_service.dart)
Add new presentation pages and widgets (e.g., pr_details_page.dart, pr_code_insights_section.dart, pr_media_section.dart, pr_ticket_link_section.dart)
Update navigation to include new routes (app_navigation.dart)
Update or refactor existing widgets and list tiles to integrate the new feature
Update data sources and providers as needed
```

### Provider Restructuring Into Feature Folders

Refactors frontend provider files from a flat structure into feature-specific folders, updating all relevant imports and usages.

**Frequency**: ~2 times per month

**Steps**:
1. Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
2. Update all import statements across the codebase to the new provider paths
3. Test and verify that all features using providers function correctly

**Files typically involved**:
- `frontend/lib/presentation/providers/*.dart`
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/app.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/presentation/pages/**/*.dart`

**Example commit sequence**:
```
Move provider files from frontend/lib/presentation/providers/ to frontend/lib/presentation/pages/<feature>/providers/
Update all import statements across the codebase to the new provider paths
Test and verify that all features using providers function correctly
```

### Frontend Widget Refactor And Enhancement

Refactors and enhances frontend widgets, often splitting large widgets into smaller components and improving their API or display capabilities.

**Frequency**: ~2 times per month

**Steps**:
1. Move widget code into dedicated files within widgets/ directories
2. Enhance widget APIs (e.g., add richValue, assertions, or new properties)
3. Update all usages of the refactored widgets in presentation pages
4. Test UI to ensure no regressions

**Files typically involved**:
- `frontend/lib/presentation/pages/open_prs/widgets/*.dart`
- `frontend/lib/presentation/widgets/kpi_card.dart`
- `frontend/lib/presentation/pages/open_prs/open_prs_page.dart`

**Example commit sequence**:
```
Move widget code into dedicated files within widgets/ directories
Enhance widget APIs (e.g., add richValue, assertions, or new properties)
Update all usages of the refactored widgets in presentation pages
Test UI to ensure no regressions
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
