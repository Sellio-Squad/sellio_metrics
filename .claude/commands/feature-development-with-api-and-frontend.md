---
name: feature-development-with-api-and-frontend
description: Workflow command scaffold for feature-development-with-api-and-frontend in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /feature-development-with-api-and-frontend

Use this workflow when working on **feature-development-with-api-and-frontend** in `sellio_metrics`.

## Goal

Implements a new feature that involves both backend (API/database) and frontend (UI) changes, often including new endpoints, data models, and UI pages/components.

## Common Files

- `backend/src/**/*.ts`
- `backend/migrations/*.sql`
- `docs/*.json`
- `frontend/lib/data/repositories/**/*.dart`
- `frontend/lib/domain/entities/**/*.dart`
- `frontend/lib/presentation/pages/**/*.dart`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update backend logic (e.g., new endpoint, service, or database migration).
- Update backend types and/or migrations if needed.
- Update or add frontend data repositories/entities to consume new API or data.
- Implement new or updated frontend pages/components to display the feature.
- Update localization files if new UI text is added.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.