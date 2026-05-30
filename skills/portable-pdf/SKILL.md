---
name: portable-pdf
description: Use this when a user asks to inspect, triage, map, or sanity-check a PDF portably using moonrun and the bundled pdfskill WASM artifact from this skill.
---

# Portable PDF

Use this skill for fast PDF triage in an agent workflow. It runs a bundled
MoonBit WASIp1 command through `moonrun`, so there is no build step when the
skill is installed.

## Quick Start

Run the bundled WASM artifact from a directory where the target PDF is visible:

```sh
cd /path/to/workdir
moonrun /path/to/portable-pdf/assets/pdfskill.wasm brief input.pdf
```

Use `doctor` for a compact pass/warn summary:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm doctor input.pdf
```

Use `map` to list indirect object candidates and byte offsets:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm map --limit 80 input.pdf
```

Write a machine-readable report when another tool should consume it:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm brief --json -o pdf-brief.json input.pdf
```

## Workflow

1. Start with `doctor` to detect malformed structure and obvious active-content
   signals.
2. Use `brief` when the result should be pasted into a conversation or saved as
   task context.
3. Use `map` when debugging offsets, cross-reference repair, or suspicious
   object placement.
4. Treat `risk: active-content`, `risk: encrypted`, and `risk: review` as
   routing signals for deeper PDF tooling.
5. Prefer running from the work directory and passing relative paths, because
   this skill intentionally relies on minimal portable WASI file access.

## Caveats

This is byte-level triage backed by `pdflite/reader` header/startxref parsing.
It does not render pages, execute JavaScript, decrypt PDFs, extract semantic
text, validate signatures, or fully interpret object streams.
