---
name: portable-diffskill
description: Use this when a user asks to summarize, triage, or review a local unified diff or patch using moonrun and the bundled portable diffskill WASM artifact from this skill.
---

# Portable Diffskill

Use this skill to convert a unified diff into a compact review report. It is
best for quick code-review triage when the agent has a patch file but should not
depend on Git commands.

## Quick Start

```sh
moonrun /path/to/portable-diffskill/assets/diffskill.wasm \
  --file change.diff
```

Limit file listing size:

```sh
moonrun /path/to/portable-diffskill/assets/diffskill.wasm \
  --limit 20 \
  --file change.diff
```

## Workflow

1. Generate or locate a unified diff.
2. Run `diffskill` to get changed files, line counts, risk tags, and review
   hints.
3. Pay special attention to `artifact`, `manifest`, and `automation` tags.
4. Use the report to decide which tests or source files need deeper inspection.

## Useful Options

- `--file PATH`: read a guest-visible diff file.
- `--limit N`: cap changed files listed in the report.
- `--output PATH`: write the report to a guest-visible path.

## Caveats

This skill parses unified diff text. It does not call Git, inspect repository
state, understand renames beyond paths present in the diff, or prove test
coverage.
