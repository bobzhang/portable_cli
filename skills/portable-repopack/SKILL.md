---
name: portable-repopack
description: Use this when a user asks to pack, bundle, or snapshot a repository or directory into compact Markdown context for an agent, using moonrun and the bundled portable repopack WASM artifact from this skill.
---

# Portable Repopack

Use this skill to turn a WASI-visible project directory into deterministic
Markdown context. It is best for quick agent handoffs, codebase snapshots, and
small-to-medium source trees where stable text output matters more than deep
Git awareness.

## Quick Start

Run the bundled WASM artifact with `moonrun` from the project directory:

```sh
cd /path/to/project
moonrun /path/to/portable-repopack/assets/repopack.wasm --redact-secrets --stats --budget-chars 30000 .
```

If changing directories is inconvenient, use the helper wrapper:

```sh
skills/portable-repopack/scripts/repopack-moonrun.sh \
  --workdir /path/to/project \
  -- --redact-secrets --stats --budget-chars 30000 .
```

Write the bundle to a file inside the selected workdir:

```sh
skills/portable-repopack/scripts/repopack-moonrun.sh \
  --workdir /path/to/project \
  -- --max-files 80 --max-chars 8000 --output repo-pack.md .
```

## Workflow

1. Choose the smallest useful `--workdir`.
2. Use `--budget-chars` to keep included file content within the task budget.
3. Use `--ext` for focused tasks, for example `--ext mbt,md,json`.
4. Use `--redact-secrets` before sharing generated context outside the local
   task.
5. Use `--stats` when you want a quick extension/language summary.
6. Inspect the Markdown bundle before relying on it for analysis.
7. Prefer direct `moonrun assets/repopack.wasm`; use `scripts/repopack-moonrun.sh`
   only when a `--workdir` helper is useful.
8. Use `scripts/repopack-wasm.sh` only as a compatibility alias; it delegates to
   the `moonrun` helper.
9. If the task requires Git-aware ignores, symlink handling, byte-size limits
   before read, or streaming large files, say that this portable version is not
   a full native repo packer.

## Useful Options

- `--max-files N`: cap the number of included files.
- `--max-chars N`: cap characters per file after reading.
- `--budget-chars N`: cap total included file-content characters.
- `--stats`: include an extension summary for included files.
- `--ext a,b,c`: include only listed extensions.
- `--hidden`: include hidden entries.
- `--no-default-ignore`: disable built-in ignores.
- `--all-files`: try every readable text file.
- `--redact-secrets`: redact secret-like values before emitting file contents.
- `--output PATH`: write Markdown to a guest-visible path.

## Caveats

This skill intentionally uses the minimal `miniio` WASIp1 surface. It can walk
directories and read text files, but it does not parse `.gitignore`, inspect
symlinks, stream large files, or get file size before reading. Secret redaction
is heuristic; use `portable-secretscan` first when sharing risk is high.
