---
name: portable-secretscan
description: Use this when a user asks to scan a repository or directory for secret-like values before sharing, packing, or sending context to an agent, using moonrun and the bundled portable secretscan WASM artifact from this skill.
---

# Portable Secretscan

Use this skill to scan WASI-visible text files for secret-like values before
packing or sharing repository context. It is best for agent handoffs where the
first requirement is not to leak local credentials into a prompt, issue, or
generated report.

## Quick Start

Run the bundled WASM artifact with `moonrun` from the project directory:

```sh
cd /path/to/project
moonrun /path/to/portable-secretscan/assets/secretscan.wasm --fail-on high .
```

Write a redacted Markdown report:

```sh
moonrun /path/to/portable-secretscan/assets/secretscan.wasm \
  --output secret-scan.md \
  .
```

Produce compact JSON for automation:

```sh
moonrun /path/to/portable-secretscan/assets/secretscan.wasm --json .
```

## Workflow

1. Run `secretscan` before using repo-packing or context-sharing tools.
2. Start with `--fail-on high` when the result should block sharing.
3. Use `--ext env,json,md,mbt,ts` for focused scans.
4. Review source files for every finding; evidence in reports is redacted.
5. Treat a clean scan as a heuristic signal, not a guarantee.

## Useful Options

- `--json`: write compact JSON.
- `--fail-on LEVEL`: return exit status 1 for `low`, `medium`, `high`, or
  `critical` findings.
- `--max-files N`: cap the number of scanned files.
- `--max-bytes N`: cap inspected bytes per file after reading text.
- `--limit N`: cap printed findings.
- `--ext a,b,c`: include only listed extensions.
- `--hidden`: include hidden entries.
- `--no-default-ignore`: disable built-in ignores.
- `--all-files`: try every readable text file.
- `--output PATH`: write the report to a guest-visible path.

## Caveats

This skill intentionally uses minimal `miniio` WASIp1 APIs. It reads text files
and walks directories, but it does not parse `.gitignore`, stream large files,
or prove the absence of secrets. It uses conservative heuristics and redacts
matched evidence.
