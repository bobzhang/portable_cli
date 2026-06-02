---
name: docx2html
description: Use this when a user asks to convert local Word DOCX files to HTML or Markdown, apply Mammoth-style style maps, extract DOCX images beside converted HTML, or run the native MoonBit bobzhang/docx2html converter.
---

# DOCX to HTML

Use this skill to convert WASI-independent local `.docx` files with the native
MoonBit `bobzhang/docx2html` CLI. It is best for semantic DOCX conversion to
HTML or Markdown, Mammoth-style style maps, and extracted image output.

## Quick Start

Convert to HTML on stdout:

```sh
skills/docx2html/scripts/docx2html.sh input.docx > output.html
```

Convert to Markdown:

```sh
skills/docx2html/scripts/docx2html.sh \
  --output-format=markdown input.docx > output.md
```

Write HTML and extracted images into a directory:

```sh
mkdir -p out
skills/docx2html/scripts/docx2html.sh --output-dir out input.docx
```

Apply a Mammoth-style map:

```sh
skills/docx2html/scripts/docx2html.sh \
  --style-map style-map.txt input.docx output.html
```

## Workflow

1. Use `scripts/docx2html.sh --help` if you need the current CLI options.
2. Prefer stdout for one-off conversion and explicit output files for durable
   artifacts.
3. Create the `--output-dir` directory before running when images should be
   written beside the generated HTML.
4. Capture stderr when diagnostics matter; conversion warnings are written
   there.
5. Use `DOCX2HTML_BIN=/path/to/docx2html` when a known binary should be used
   instead of installing through MoonBit.

## Useful Options

- `--output-format=html|markdown`: choose HTML or Markdown output.
- `--pretty-print`: pretty-print generated HTML.
- `--style-map PATH`: read Mammoth-style mapping lines from a file.
- `--output-dir DIR`: write converted HTML plus extracted images into `DIR`.

## Caveats

This is a native MoonBit CLI skill, not a bundled Wasm `moonrun` artifact. The
wrapper installs and caches `bobzhang/docx2html/cmd/docx2html@0.1.40` with
`moon install` if `docx2html` is not already on `PATH`. The converter targets
semantic HTML/Markdown output rather than pixel-perfect Word layout, and it
handles `.docx`, not legacy `.doc` files.
