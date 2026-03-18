---
name: ecc-bundle-synchronization
description: Workflow command scaffold for ecc-bundle-synchronization in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /ecc-bundle-synchronization

Use this workflow when working on **ecc-bundle-synchronization** in `sellio_metrics`.

## Goal

Synchronize or update the ECC bundle for sellio_metrics, including commands, skills, instincts, agent configs, and tool definitions.

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

- Add or update .claude/commands/*.md files for new or changed workflows (e.g., feature-development.md, refactoring.md)
- Add or update .claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml
- Add or update .codex/agents/*.toml files (docs-researcher.toml, reviewer.toml, explorer.toml)
- Add or update .codex/AGENTS.md and .codex/config.toml
- Add or update .claude/identity.json

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.