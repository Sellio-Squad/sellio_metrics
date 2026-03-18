---
name: add-or-refactor-feature-with-new-page-and-provider
description: Workflow command scaffold for add-or-refactor-feature-with-new-page-and-provider in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-refactor-feature-with-new-page-and-provider

Use this workflow when working on **add-or-refactor-feature-with-new-page-and-provider** in `sellio_metrics`.

## Goal

Implements a new feature or refactors an existing one by adding a new page (often under open_prs, members, or observability), updating navigation, and creating or updating a provider for state management.

## Common Files

- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`
- `frontend/lib/presentation/pages/<feature>/widgets/*.dart`
- `frontend/lib/presentation/providers/<feature>_provider.dart`
- `frontend/lib/presentation/pages/<feature>/providers/<feature>_provider.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/domain/entities/*.dart`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update a new page widget under frontend/lib/presentation/pages/<feature>/
- Add or update provider under frontend/lib/presentation/providers/ or frontend/lib/presentation/pages/<feature>/providers/
- Update navigation in frontend/lib/core/navigation/app_navigation.dart
- Update or create new domain/entity/service files if needed
- Update or add widgets under frontend/lib/presentation/pages/<feature>/widgets/

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.