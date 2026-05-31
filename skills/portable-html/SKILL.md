---
name: portable-html
description: Use this when a user asks to format, sanitize, inspect, outline, audit links, extract clean text, or convert local HTML to Markdown using moonrun and the bundled portable htmlfmt WASM artifact from this skill.
---

# Portable HTML

Use this skill to format, inspect, and convert WASI-visible HTML files without a
native HTML toolchain. It is best for agent workflows that need quick page
triage, metadata extraction, link review, basic accessibility hints, clean text,
Markdown, or normalized HTML before further processing.

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

Extract readable text:

```sh
moonrun /path/to/portable-html/assets/htmlfmt.wasm \
  --text --file page.html
```

Convert HTML to Markdown:

```sh
moonrun /path/to/portable-html/assets/htmlfmt.wasm \
  --markdown --file page.html
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
4. Use `--text` for concise summaries, search snippets, or prompt context.
5. Use `--markdown` when preserving headings, lists, links, and emphasis matters.
6. Use `--sanitize` before formatting untrusted fragments.
7. Use `--limit N` to keep inspection output concise.

## Useful Options

- `--inspect`: write a Markdown inspection report instead of formatted HTML.
- `--json`: with `--inspect`, write compact JSON.
- `--text`: write clean block-oriented text.
- `--markdown`: convert the parsed HTML to Markdown.
- `--html-passthrough`: with `--markdown`, preserve unsupported source HTML.
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
