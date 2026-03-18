---
name: add-or-refactor-feature-page-with-widgets
description: Workflow command scaffold for add-or-refactor-feature-page-with-widgets in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-refactor-feature-page-with-widgets

Use this workflow when working on **add-or-refactor-feature-page-with-widgets** in `sellio_metrics`.

## Goal

Adds a new feature page or refactors an existing one by splitting logic into multiple smaller widgets/components for improved maintainability and readability.

## Common Files

- `frontend/lib/presentation/pages/<feature>/<feature>_page.dart`
- `frontend/lib/presentation/pages/<feature>/widgets/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/presentation/providers/<feature>_provider.dart`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update main page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
- Create or update multiple widget/component files in frontend/lib/presentation/pages/<feature>/widgets/
- Update navigation or routing in frontend/lib/core/navigation/app_navigation.dart if needed
- Update provider in frontend/lib/presentation/providers/<feature>_provider.dart if needed

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.