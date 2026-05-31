---
name: portable-html
description: Use this when a user asks to format, sanitize, inspect, outline, audit links, or summarize metadata from local HTML using moonrun and the bundled portable htmlfmt WASM artifact from this skill.
---

# Portable HTML

Use this skill to format and inspect WASI-visible HTML files without a native
HTML toolchain. It is best for agent workflows that need quick page triage,
metadata extraction, link review, basic accessibility hints, or normalized HTML
before further processing.

## Quick Start

Inspect a full HTML document:

```sh
moonrun /path/to/portable-html/assets/htmlfmt.wasm \
  --inspect --document --file page.html
```

Format a fragment:

```sh
moonrun /path/to/portable-html/assets/htmlfmt.wasm \
  --file fragment.html \
  --output formatted.html
```

Sanitize and compact untrusted HTML:

```sh
moonrun /path/to/portable-html/assets/htmlfmt.wasm \
  --sanitize --compact --file input.html
```

## Workflow

1. Use `--inspect --document --file PAGE` before summarizing or trusting an HTML
   document.
2. Check the report for metadata, outline, links, missing image alt text,
   scripts, and forms.
3. Use `--json` with `--inspect` when another tool should consume the report.
4. Use `--sanitize` before formatting untrusted fragments.
5. Use `--limit N` to keep inspection output concise.

## Useful Options

- `--inspect`: write a Markdown inspection report instead of formatted HTML.
- `--json`: with `--inspect`, write compact JSON.
- `--document`: parse as a full document instead of a fragment.
- `--sanitize`: apply the default sanitizer before formatting or inspection.
- `--compact`: write compact normalized HTML.
- `--indent N`: choose pretty-print indentation.
- `--limit N`: cap report rows.
- `--file PATH`: read a guest-visible file.
- `--output PATH`: write output to a guest-visible file.

## Caveats

This is a lightweight structural inspection skill. It does not execute
JavaScript, fetch linked resources, compute rendered accessibility trees, or
validate every HTML/a11y rule.
