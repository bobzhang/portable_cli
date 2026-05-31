---
name: portable-pulse
description: Use this when a user asks to summarize local plain text, count words, or produce a compact word-frequency histogram using moonrun and the bundled portable pulse WASM artifact from this skill.
---

# Portable Pulse

Use this skill for quick text triage in an agent workflow. It runs a bundled
MoonBit WASIp1 command through `moonrun`, so there is no build step when the
skill is installed.

## Quick Start

Summarize a text file:

```sh
moonrun /path/to/portable-pulse/assets/pulse.wasm \
  --file notes.txt \
  --top 12
```

Keep output compact for prompt context:

```sh
moonrun /path/to/portable-pulse/assets/pulse.wasm \
  --file notes.txt \
  --top 5 \
  --width 16
```

Preserve original case for acronyms or identifiers:

```sh
moonrun /path/to/portable-pulse/assets/pulse.wasm \
  --file notes.txt \
  --preserve-case
```

## Workflow

1. Use `--file PATH` for guest-visible text files and stdin for piped text.
2. Use `--top N` to keep the histogram short enough for context.
3. Use `--width N` to keep bar output compact.
4. Add `--preserve-case` when case distinguishes tokens such as API names.

## Useful Options

- `--file PATH`: read a guest-visible text file.
- `--top N`: number of words to show.
- `--width N`: maximum histogram bar width.
- `--preserve-case`: keep original word case.

## Caveats

This is a small lexical summary, not a natural-language analysis engine. It
does not stem words, remove stop words, detect language, parse Markdown
structure, or stream very large files.
