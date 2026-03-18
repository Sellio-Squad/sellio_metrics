---
name: feature-development-with-page-and-widgets
description: Workflow command scaffold for feature-development-with-page-and-widgets in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /feature-development-with-page-and-widgets

Use this workflow when working on **feature-development-with-page-and-widgets** in `sellio_metrics`.

## Goal

Implements a new feature page or enhances an existing one with supporting widgets, navigation, and data providers.

## Common Files

- `frontend/lib/presentation/pages/*/*_page.dart`
- `frontend/lib/presentation/pages/*/widgets/*.dart`
- `frontend/lib/presentation/pages/*/providers/*.dart`
- `frontend/lib/core/navigation/app_navigation.dart`
- `frontend/lib/l10n/app_ar.arb`
- `frontend/lib/l10n/app_en.arb`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update a page file in frontend/lib/presentation/pages/<feature>/<feature>_page.dart
- Add or update supporting widgets in frontend/lib/presentation/pages/<feature>/widgets/
- Update or add providers in frontend/lib/presentation/pages/<feature>/providers/
- Update navigation in frontend/lib/core/navigation/app_navigation.dart
- Update or create domain/data entities and services as needed

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.