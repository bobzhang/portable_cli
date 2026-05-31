---
name: portable-jqlet
description: Use this when a user asks to format, compact, validate, or extract simple dotted paths from local JSON using moonrun and the bundled portable jqlet WASM artifact from this skill.
---

# Portable Jqlet

Use this skill for small JSON shaping tasks in an agent workflow. It runs a
bundled MoonBit WASIp1 command through `moonrun`, so there is no build step when
the skill is installed.

## Quick Start

Pretty-print a JSON file:

```sh
moonrun /path/to/portable-jqlet/assets/jqlet.wasm --file data.json
```

Extract a simple dotted or indexed path:

```sh
moonrun /path/to/portable-jqlet/assets/jqlet.wasm \
  --file data.json \
  --get 'items[0].name' \
  --raw
```

Write compact output for another tool:

```sh
moonrun /path/to/portable-jqlet/assets/jqlet.wasm \
  --file data.json \
  --get ok \
  --compact \
  --output ok.json
```

## Workflow

1. Use `--file PATH` for guest-visible files and stdin for piped JSON.
2. Use `--get PATH` for simple object fields and array indexes.
3. Add `--raw` when extracting a string for shell or prompt use.
4. Add `--compact` when another tool should consume the JSON.
5. Use `--output PATH` when a later step needs a real file artifact.

## Useful Options

- `--file PATH`: read a guest-visible JSON file.
- `--get PATH`: extract `user.name`, `items[0].id`, or similar paths.
- `--raw`: print selected JSON strings without quotes.
- `--compact`: print compact JSON.
- `--indent N`: choose pretty-print indentation.
- `--output PATH`: write output to a guest-visible file.

## Caveats

This is a deliberately small JSON formatter and path extractor. It is not a full
`jq` replacement: it does not support filters, updates, recursive descent,
streaming, arithmetic, or custom functions.
