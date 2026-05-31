---
name: portable-tree
description: Use this when a user asks to inspect local directory layout, list a project tree, include hidden entries, or show directories only using moonrun and the bundled portable tree WASM artifact from this skill.
---

# Portable Tree

Use this skill to get a deterministic directory overview in an agent workflow.
It runs a bundled MoonBit WASIp1 command through `moonrun`, so there is no build
step when the skill is installed.

## Quick Start

Show a shallow project tree:

```sh
moonrun /path/to/portable-tree/assets/tree.wasm --depth 2 .
```

Include hidden entries:

```sh
moonrun /path/to/portable-tree/assets/tree.wasm --all --depth 2 .
```

Show only directories:

```sh
moonrun /path/to/portable-tree/assets/tree.wasm --dirs-only --all .
```

## Workflow

1. Start with `--depth 2` or `--depth 3` for a compact overview.
2. Add `--all` when dotfiles or hidden configuration are relevant.
3. Add `--dirs-only` for a high-level package or repository map.
4. Run from the work directory and pass relative paths visible to WASI.

## Useful Options

- `--depth N`: maximum recursion depth.
- `--all`: include hidden entries.
- `--dirs-only`: show directories only.
- `PATH`: root path, defaulting to `.`.

## Caveats

This is a lightweight directory renderer. It does not report file sizes,
permissions, symlink targets, modification times, or ignored-file status.
