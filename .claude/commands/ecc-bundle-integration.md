---
name: ecc-bundle-integration
description: Workflow command scaffold for ecc-bundle-integration in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /ecc-bundle-integration

Use this workflow when working on **ecc-bundle-integration** in `sellio_metrics`.

## Goal

Integrates or updates the sellio_metrics ECC bundle and related agent/configuration files for the Claude/Codex/Agents system.

## Common Files

- `.claude/commands/*.md`
- `.claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml`
- `.codex/agents/*.toml`
- `.codex/AGENTS.md`
- `.codex/config.toml`
- `.claude/identity.json`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Add or update .claude/commands/*.md files (e.g., feature-development.md, refactoring.md, add-or-refactor-feature-with-new-page-and-provider.md)
- Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
- Add or update .codex/agents/*.toml files (e.g., docs-researcher.toml, reviewer.toml, explorer.toml)
- Add or update .codex/AGENTS.md and .codex/config.toml
- Add or update .claude/identity.json

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.