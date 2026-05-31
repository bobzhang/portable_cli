---
name: portable-toml
description: Use this when a user asks to inspect TOML-style config, inventory tables and keys, find duplicate keys or tables, extract dotted values, normalize simple TOML, or produce JSON config summaries using moonrun and the bundled portable tomlskill WASM artifact.
---

# Portable TOML

Use this skill to inspect WASI-visible TOML-style config files without a native
TOML toolchain. It is best for agent workflows that need a quick table/key
inventory, duplicate detection, simple normalization, or targeted value
extraction from config files.

## Quick Start

Print the full report:

```sh
moonrun /path/to/portable-toml/assets/tomlskill.wasm \
  --file config.toml
```

Extract a dotted key:

```sh
moonrun /path/to/portable-toml/assets/tomlskill.wasm \
  --get package.version --raw --file config.toml
```

Normalize simple TOML:

```sh
moonrun /path/to/portable-toml/assets/tomlskill.wasm \
  --format --file config.toml --output formatted.toml
```

Emit JSON for automation:

```sh
moonrun /path/to/portable-toml/assets/tomlskill.wasm \
  --json --file config.toml
```

## Workflow

1. Use the default report before changing unfamiliar config files.
2. Check the Issues section for duplicate tables, duplicate keys, empty values,
   or unrecognized lines.
3. Use `--get PATH --raw` when another tool needs a single value.
4. Use `--format` to strip comments and normalize simple key/table layout.
5. Use `--json` when another tool should consume the config inventory.

## Useful Options

- `--file PATH`: read a guest-visible TOML file.
- `--get PATH`: extract a dotted key path.
- `--raw`: with `--get`, write only the raw value.
- `--format`: write normalized simple TOML.
- `--section NAME`: print one report section: `summary`, `tables`, `keys`, or
  `issues`.
- `--json`: write a compact JSON inventory.
- `--limit N`: cap rows in Markdown sections.
- `--output PATH`: write output to a guest-visible file.

## Caveats

This is a lightweight scanner for common TOML-style config. It does not
implement the full TOML specification, preserve comments, or validate every
string/date/number edge case.
