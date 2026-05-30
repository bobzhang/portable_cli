---
name: portable-repopack
description: Use this when a user asks to pack, bundle, or snapshot a repository or directory into compact Markdown context for an agent, using moonrun and the portable repopack CLI from this repo.
---

# Portable Repopack

Use this skill to turn a WASI-visible project directory into deterministic
Markdown context. It is best for quick agent handoffs, codebase snapshots, and
small-to-medium source trees where stable text output matters more than deep
Git awareness.

## Quick Start

Run the bundled wrapper script. It builds `cmd/repopack` as release WASM when
needed, then executes the artifact with `moonrun` from the selected workdir:

```sh
skills/portable-repopack/scripts/repopack-moonrun.sh \
  --workdir /path/to/project \
  -- --max-files 80 --max-chars 8000 .
```

Write the bundle to a file inside the preopened workdir:

```sh
skills/portable-repopack/scripts/repopack-moonrun.sh \
  --workdir /path/to/project \
  -- --max-files 80 --max-chars 8000 --output repo-pack.md .
```

## Workflow

1. Choose the smallest useful `--workdir`.
2. Use `--max-files` and `--max-chars` to keep output within the task budget.
3. Use `--ext` for focused tasks, for example `--ext mbt,md,json`.
4. Inspect the Markdown bundle before relying on it for analysis.
5. Use `scripts/repopack-wasm.sh` only as a compatibility alias; it delegates to
   the `moonrun` wrapper.
6. If the task requires Git-aware ignores, symlink handling, byte-size limits
   before read, or streaming large files, say that this portable version is not
   a full native repo packer.

## Useful Options

- `--max-files N`: cap the number of included files.
- `--max-chars N`: cap characters per file after reading.
- `--ext a,b,c`: include only listed extensions.
- `--hidden`: include hidden entries.
- `--no-default-ignore`: disable built-in ignores.
- `--all-files`: try every readable text file.
- `--output PATH`: write Markdown to a guest-visible path.

## Caveats

This skill intentionally uses the minimal `miniio` WASIp1 surface. It can walk
directories and read text files, but it does not parse `.gitignore`, inspect
symlinks, stream large files, or get file size before reading.
