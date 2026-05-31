---
name: portable-markdown
description: Use this when a user asks to inspect Markdown structure, extract outlines, inventory links/tasks/code fences/front matter, or produce JSON document summaries using moonrun and the bundled portable mdskill WASM artifact.
---

# Portable Markdown

Use this skill to inspect WASI-visible Markdown files without a native Markdown
toolchain. It is best for agent workflows that need document outlines, link
inventories, task lists, code fence maps, front matter summaries, or structural
issue checks before editing or summarizing a document.

## Quick Start

Print the full report:

```sh
moonrun /path/to/portable-markdown/assets/mdskill.wasm \
  --file README.md
```

Print only the outline:

```sh
moonrun /path/to/portable-markdown/assets/mdskill.wasm \
  --section outline --file README.md
```

Emit JSON for automation:

```sh
moonrun /path/to/portable-markdown/assets/mdskill.wasm \
  --json --file README.md
```

## Workflow

1. Use the default report before summarizing a long Markdown document.
2. Use `--section outline`, `--section links`, `--section tasks`, or
   `--section code` when the agent only needs one compact view.
3. Use `--json` when another tool should consume the structure.
4. Check the Issues section for duplicate heading slugs, empty link targets,
   unclosed front matter, or unclosed code fences.
5. Use `--limit N` to keep report sections short.

## Useful Options

- `--file PATH`: read a guest-visible Markdown file.
- `--section NAME`: print one section: `summary`, `frontmatter`, `outline`,
  `links`, `tasks`, `code`, or `issues`.
- `--json`: write a compact JSON inventory.
- `--limit N`: cap rows in each section.
- `--output PATH`: write output to a guest-visible file.

## Caveats

This is a lightweight Markdown structure scanner. It does not implement the full
CommonMark grammar, resolve reference links, render Markdown, or validate
external URLs.
