---
name: ecc-bundle-sync
description: Workflow command scaffold for ecc-bundle-sync in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /ecc-bundle-sync

Use this workflow when working on **ecc-bundle-sync** in `sellio_metrics`.

## Goal

Synchronize or update ECC (Enhanced Code Context) bundle files for the sellio_metrics project, including commands, skills, agent configs, and tool manifests.

## Common Files

- `.claude/commands/feature-development.md`
- `.claude/commands/refactoring.md`
- `.claude/commands/add-or-refactor-feature-with-new-page-and-provider.md`
- `.claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml`
- `.codex/agents/docs-researcher.toml`
- `.codex/agents/reviewer.toml`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Add or update .claude/commands/*.md files (feature-development, refactoring, add-or-refactor-feature-with-new-page-and-provider)
- Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
- Add or update .codex/agents/*.toml files (docs-researcher, reviewer, explorer)
- Add or update .codex/AGENTS.md and .codex/config.toml
- Add or update .claude/identity.json

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.