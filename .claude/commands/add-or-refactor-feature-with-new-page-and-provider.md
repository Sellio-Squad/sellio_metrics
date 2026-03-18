---
name: add-or-refactor-feature-with-new-page-and-provider
description: Workflow command scaffold for add-or-refactor-feature-with-new-page-and-provider in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-refactor-feature-with-new-page-and-provider

Use this workflow when working on **add-or-refactor-feature-with-new-page-and-provider** in `sellio_metrics`.

## Goal

Adds or refactors a frontend feature by creating or updating a page, its provider, and related widgets/components, often including navigation updates and entity changes.

## Common Files

- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/presentation/pages/*/providers/*_provider.dart`
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/domain/entities/*.dart`
- `frontend/lib/domain/services/*.dart`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update a page under frontend/lib/presentation/pages/<feature>/<feature>_page.dart
- Create or update provider under frontend/lib/presentation/pages/<feature>/providers/<feature>_provider.dart or frontend/lib/presentation/providers/<feature>_provider.dart
- Add or update widgets/components under frontend/lib/presentation/pages/<feature>/widgets/
- Update navigation in frontend/lib/core/navigation/app_navigation.dart
- Update or add related entities or services under frontend/lib/domain/entities/ or frontend/lib/domain/services/

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.