---
name: portable-datascout
description: Use this when a user asks to inspect, summarize, profile, sample, or infer schema for local CSV/TSV-like data using moonrun and the bundled portable datascout WASM artifact from this skill.
---

# Portable Datascout

Use this skill to turn a local delimited data file into a compact schema and
sample report. It is useful before sending data to an agent because it exposes
column names, inferred simple types, empty counts, max lengths, and a bounded
sample without loading the full file into the conversation.

## Quick Start

```sh
moonrun /path/to/portable-datascout/assets/datascout.wasm \
  --file data.csv \
  --sample 5
```

Write JSON for automation:

```sh
moonrun /path/to/portable-datascout/assets/datascout.wasm \
  --json \
  --file data.csv
```

For TSV or semicolon-delimited files:

```sh
moonrun /path/to/portable-datascout/assets/datascout.wasm \
  --delimiter tab \
  --file data.tsv
```

## Workflow

1. Run `datascout` before pasting or packing large data files.
2. Use `--sample N` to keep examples small.
3. Use `--max-rows N` to cap scan work for large files.
4. Use `--json` when another tool should consume the schema.
5. Use `--no-header` when the first row is data.

## Useful Options

- `--file PATH`: read a guest-visible data file.
- `--json`: write compact JSON.
- `--delimiter auto|comma|tab|semicolon|CHAR`: select delimiter.
- `--sample N`: number of sample rows to include.
- `--max-rows N`: maximum rows to scan.
- `--no-header`: synthesize `column_1`, `column_2`, ...
- `--output PATH`: write report to a guest-visible path.

## Caveats

This is a lightweight profiler, not a full dataframe engine. CSV quote handling
is enough for common files, but it does not stream rows, validate encodings, or
run SQL-like queries.
