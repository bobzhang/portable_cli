# portable_cli

Small MoonBit WASIp1 command-line programs that use
`moonbit-community/miniio` for portable I/O and `moonbitlang/core/argparse` for
declarative CLI parsing.

## Commands

- `cmd/cow`: a cowsay-style filter. It accepts words as arguments or reads
  stdin, supports `--width`, `--eyes`, `--tongue`, and `--think`.
- `cmd/htmlfmt`: HTML formatter backed by `bobzhang/html_parser`. It reads
  stdin, inline HTML, or `--file`, supports fragment/document parsing,
  `--compact`, `--indent`, `--sanitize`, `--strict`, and `--output`.
- `cmd/jqlet`: JSON formatter and simple path extractor. It reads stdin or
  `--file`, supports `--get`, `--raw`, `--compact`, `--indent`, and `--output`.
- `cmd/repopack`: repository context packer for WASI-visible text files. It
  walks directories deterministically, skips common build/dependency folders by
  default, caps file content, and emits Markdown.
- `cmd/tree`: deterministic directory tree rendering over guest-visible WASI
  paths. It supports `--depth`, `--all`, and `--dirs-only`.
- `cmd/pulse`: text statistics and word-frequency bars from stdin or
  `--file`.

## Run With Moon

```sh
moon run --target wasm cmd/cow -- portable wasm cli
moon run --target wasm cmd/htmlfmt -- '<article><p>Hello <b>MoonBit</b></p></article>'
printf '{"items":[{"name":"moon"}]}\n' | moon run --target wasm cmd/jqlet -- --get 'items[0].name' --raw
moon run --target wasm cmd/repopack -- --max-files 12 --max-chars 2000 .
moon run --target wasm cmd/tree -- --depth 2 .
printf 'wasm wasm portable cli\n' | moon run --target wasm cmd/pulse -- --top 3
```

## Run With Wasmtime

Build the WASIp1 modules:

```sh
moon build --target wasm cmd/cow cmd/htmlfmt cmd/jqlet cmd/repopack cmd/tree cmd/pulse
```

Then run a built module with explicit preopened paths:

```sh
wasmtime run \
  --dir .::. \
  --preload __moonbit_sys_unstable=wasm/moonbit-sys-unstable.wat \
  _build/wasm/debug/build/cmd/tree/tree.wasm \
  --depth 2 .
```

The preload module forwards the current MoonBit `@argparse` wasm exit shim to
WASI `proc_exit`, which lets help/version handling run under plain Wasmtime.

Use `scripts/smoke.sh` to exercise all commands through `moon run --target wasm`
and direct `wasmtime` when `wasmtime` is installed.

## Cram Tests

The Cram suite records shell-visible CLI behavior for the WASM target and
doubles as runnable command documentation:

```sh
moon cram test tests/cram
```

See `tests/cram/wasm_cli.md` for the checked examples.

The tests intentionally invoke packages with `moon run --target wasm` instead
of native `.exe` binaries because the examples are portable `miniio` WASIp1
programs.

## Codex Skill

This repo also includes a prototype Codex skill at
`skills/portable-repopack`. It uses the release `cmd/repopack` WASM artifact
through Wasmtime to pack a project directory into Markdown context:

```sh
skills/portable-repopack/scripts/repopack-wasm.sh \
  --workdir . \
  -- --max-files 80 --max-chars 8000 .
```
