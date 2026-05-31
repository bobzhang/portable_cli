---
name: portable-svg
description: Use this when a user asks to inspect SVG files, inventory SVG structure, detect risky SVG features, or produce JSON SVG triage using moonrun and the bundled portable svgcheck WASM artifact.
---

# Portable SVG

Use this skill to inspect WASI-visible SVG files without a native image or XML
toolchain. It is best for agent workflows that need quick asset triage before
embedding, rewriting, reviewing, or sharing SVG content.

## Quick Start

Print a Markdown risk report:

```sh
moonrun /path/to/portable-svg/assets/svgcheck.wasm \
  --file icon.svg
```

Emit JSON for automation:

```sh
moonrun /path/to/portable-svg/assets/svgcheck.wasm \
  --json --file icon.svg
```

Fail an automated workflow on high-risk signals:

```sh
moonrun /path/to/portable-svg/assets/svgcheck.wasm \
  --fail-on high --file icon.svg
```

## Workflow

1. Run the default report before embedding SVG supplied by a user or generated
   by another tool.
2. Check the Issues section for scripts, event handlers, JavaScript URLs,
   external references, `foreignObject`, or malformed tags.
3. Use `--json` when another tool should consume the inventory.
4. Use `--fail-on high` or `--fail-on medium` in checks that should reject risky
   assets.
5. Use `--limit N` to keep tag and issue tables concise.

## Useful Options

- `--file PATH`: read a guest-visible SVG file.
- `--json`: write a compact JSON report.
- `--fail-on LEVEL`: exit non-zero for issues at or above `high`, `medium`,
  `low`, or `none`.
- `--limit N`: cap tag counts and issues in Markdown output.
- `--output PATH`: write output to a guest-visible file.

## Caveats

This is a lightweight scanner, not a full XML validator or sanitizer. It is
designed to surface common SVG risk signals quickly and portably.
