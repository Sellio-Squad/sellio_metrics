---
name: add-or-update-ecc-bundle
description: Workflow command scaffold for add-or-update-ecc-bundle in sellio_metrics.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-update-ecc-bundle

Use this workflow when working on **add-or-update-ecc-bundle** in `sellio_metrics`.

## Goal

Adds or updates ECC (Extensible Command/Capability) bundle files for the sellio_metrics project, including commands, skills, agent configs, and documentation.

## Common Files

- `.claude/commands/*.md`
- `.claude/skills/sellio_metrics/SKILL.md`
- `.claude/homunculus/instincts/inherited/sellio_metrics-instincts.yaml`
- `.codex/agents/*.toml`
- `.codex/AGENTS.md`
- `.codex/config.toml`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Add or update files in .claude/commands/, .claude/skills/, .claude/homunculus/instincts/inherited/, .codex/agents/, .codex/, .agents/skills/sellio_metrics/
- Commit with message referencing 'add sellio_metrics ECC bundle'

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.