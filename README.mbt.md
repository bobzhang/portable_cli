# portable_cli

Small MoonBit WASIp1 command-line programs that use
`moonbit-community/miniio` for portable I/O and `moonbitlang/core/argparse` for
declarative CLI parsing.

## Commands

- `cmd/cow`: a cowsay-style filter. It accepts words as arguments or reads
  stdin, supports `--width`, `--eyes`, `--tongue`, and `--think`.
- `cmd/datascout`: CSV/TSV-like data triage. It infers simple column types,
  empty counts, max lengths, and bounded sample rows as Markdown or JSON.
- `cmd/diffskill`: review-focused unified diff summarizer. It counts changed
  files, additions, deletions, hunks, risk tags, and review hints.
- `cmd/htmlfmt`: HTML formatter and inspector backed by
  `bobzhang/html_parser`. It reads stdin, inline HTML, or `--file`, supports
  fragment/document parsing, `--compact`, `--indent`, `--sanitize`, `--strict`,
  `--inspect`, and `--output`.
- `cmd/jqlet`: JSON formatter and simple path extractor. It reads stdin or
  `--file`, supports `--get`, `--raw`, `--compact`, `--indent`, and `--output`.
- `cmd/pdfskill`: portable PDF tooling built on small `bobzhang/pdflite`
  packages. It reports structure/risk signals, maps pages, inspects objects and
  streams, inventories images and actions, extracts lightweight metadata, text,
  links, forms, and attachments, and can create a simple one-page text PDF.
- `cmd/repopack`: repository context packer for WASI-visible text files. It
  walks directories deterministically, skips common build/dependency folders by
  default, caps file content, optionally redacts secret-like values, and emits
  Markdown.
- `cmd/secretscan`: redacted secret-like value scanner for WASI-visible text
  files. It helps inspect a repo before packing or sharing context with an
  agent.
- `cmd/tree`: deterministic directory tree rendering over guest-visible WASI
  paths. It supports `--depth`, `--all`, and `--dirs-only`.
- `cmd/pulse`: text statistics and word-frequency bars from stdin or
  `--file`.

## Run With Moon

```sh
moon run --target wasm cmd/cow -- portable wasm cli
moon run --target wasm cmd/datascout -- --file data.csv --sample 3
moon run --target wasm cmd/diffskill -- --file change.diff
moon run --target wasm cmd/htmlfmt -- '<article><p>Hello <b>MoonBit</b></p></article>'
moon run --target wasm cmd/htmlfmt -- --inspect --document --file page.html
printf '{"items":[{"name":"moon"}]}\n' | moon run --target wasm cmd/jqlet -- --get 'items[0].name' --raw
moon run --target wasm cmd/pdfskill -- brief input.pdf
moon run --target wasm cmd/pdfskill -- make-text -o output.pdf Hello from MoonBit
moon run --target wasm cmd/repopack -- --redact-secrets --stats --budget-chars 30000 .
moon run --target wasm cmd/secretscan -- --fail-on high .
moon run --target wasm cmd/tree -- --depth 2 .
printf 'wasm wasm portable cli\n' | moon run --target wasm cmd/pulse -- --top 3
```

## Run With Wasmtime

Build the WASIp1 modules:

```sh
moon build --target wasm cmd/cow cmd/datascout cmd/diffskill cmd/htmlfmt cmd/jqlet cmd/pdfskill cmd/repopack cmd/secretscan cmd/tree cmd/pulse
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

See `tests/cram/` for the checked examples. Each portable command has a focused
Markdown page with a CLI flag summary, fixtures, and checked transcripts;
`wasm_cli.md` is the suite index.

The command tests invoke packages with `moon run --target wasm` instead of
native `.exe` binaries, and the skill test invokes its bundled `.wasm` with
`moonrun`.

## Codex Skill

This repo also includes prototype Codex skills under `skills/`. They bundle
release WASM artifacts and run through `moonrun`, so the agent does not need a
MoonBit build step:

```sh
moonrun skills/portable-repopack/assets/repopack.wasm --redact-secrets --stats --budget-chars 30000 .
moonrun skills/portable-secretscan/assets/secretscan.wasm --fail-on high .
moonrun skills/portable-datascout/assets/datascout.wasm --file data.csv --sample 3
moonrun skills/portable-diffskill/assets/diffskill.wasm --file change.diff
moonrun skills/portable-html/assets/htmlfmt.wasm --inspect --document --file page.html
moonrun skills/portable-pdf/assets/pdfskill.wasm doctor input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm pages input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm images input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm actions input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm text input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm links input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm forms input.pdf
moonrun skills/portable-pdf/assets/pdfskill.wasm attachments --extract-dir attachments input.pdf
```
