---
name: ecc-bundle-onboarding
description: Workflow command scaffold for ecc-bundle-onboarding in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /ecc-bundle-onboarding

Use this workflow when working on **ecc-bundle-onboarding** in `sellio_metrics`.

## Goal

Adds a new ECC bundle for sellio_metrics, including commands, skills, agents, and configuration files for Claude and Codex ecosystems.

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

- Add or update .claude/commands/*.md files (feature-development, refactoring, etc.)
- Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
- Add or update .codex/agents/*.toml files (docs-researcher, reviewer, explorer)
- Add or update .codex/AGENTS.md and .codex/config.toml
- Add or update .claude/identity.json

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.