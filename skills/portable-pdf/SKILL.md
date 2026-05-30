---
name: portable-pdf
description: Use this when a user asks to inspect, triage, map, extract lightweight text/metadata from, or create a simple PDF portably using moonrun and the bundled pdfskill WASM artifact from this skill.
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

Use `objects` and `streams` when the question needs structure beyond the brief:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm objects --limit 80 input.pdf
moonrun /path/to/portable-pdf/assets/pdfskill.wasm streams --decode --max-bytes 120 input.pdf
```

Use `metadata` and `text` for lightweight extraction:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm metadata input.pdf
moonrun /path/to/portable-pdf/assets/pdfskill.wasm text --max-chars 2000 input.pdf
```

Use `make-text` to create a simple one-page PDF:

```sh
moonrun /path/to/portable-pdf/assets/pdfskill.wasm make-text -o output.pdf --title "Portable PDF" Hello from a portable skill
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
3. Use `objects` and `streams` when debugging offsets, filters, or suspicious
   object placement.
4. Use `metadata` and `text` for bounded extraction before escalating to a
   heavier renderer or semantic parser.
5. Use `make-text` when an agent needs to emit a minimal PDF without depending
   on host tools.
6. Treat `risk: active-content`, `risk: encrypted`, and `risk: review` as
   routing signals for deeper PDF tooling.
7. Prefer running from the work directory and passing relative paths, because
   this skill intentionally relies on minimal portable WASI file access.

## Caveats

This is lightweight portable PDF tooling backed by small `pdflite` packages and
bounded byte/object parsing. It does not render pages, execute JavaScript,
decrypt PDFs, perform OCR, validate signatures, reconstruct layout, or fully
interpret object streams.
