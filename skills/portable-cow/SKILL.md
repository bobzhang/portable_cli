---
name: portable-cow
description: Use this when a user asks for a small portable ASCII cow text bubble, a playful CLI smoke test, or a minimal moonrun demo using the bundled portable cow WASM artifact from this skill.
---

# Portable Cow

Use this skill for a tiny, visible portable CLI demonstration. It runs a bundled
MoonBit WASIp1 command through `moonrun`, so there is no build step when the
skill is installed.

## Quick Start

Render a speech bubble:

```sh
moonrun /path/to/portable-cow/assets/cow.wasm --width 24 portable wasm cli
```

Render a thought bubble:

```sh
moonrun /path/to/portable-cow/assets/cow.wasm \
  --think \
  --eyes ^^ \
  MoonBit runs here
```

## Workflow

1. Use this as a compact `moonrun` smoke test when validating portable skill
   setup.
2. Pass message words as arguments, or pipe stdin when integrating with another
   command.
3. Use `--width N` to keep the bubble readable in narrow outputs.

## Useful Options

- `--width N`: bubble wrap width.
- `--think`: use a thought-bubble tail.
- `--eyes TEXT`: two-character eyes.
- `--tongue TEXT`: two-character tongue.

## Caveats

This is intentionally playful. For operational text analysis, prefer
`portable-pulse`; for repository context, prefer `portable-repopack`.
