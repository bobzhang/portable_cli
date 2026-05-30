# portable_cli

Small MoonBit WASIp1 command-line programs that use
`moonbit-community/miniio` for portable I/O and `moonbitlang/core/argparse` for
declarative CLI parsing.

## Commands

- `cmd/cow`: a cowsay-style filter. It accepts words as arguments or reads
  stdin, supports `--width`, `--eyes`, `--tongue`, and `--think`.
- `cmd/tree`: deterministic directory tree rendering over guest-visible WASI
  paths. It supports `--depth`, `--all`, and `--dirs-only`.
- `cmd/pulse`: text statistics and word-frequency bars from stdin or
  `--file`.

## Run With Moon

```sh
moon run --target wasm cmd/cow portable wasm cli
moon run --target wasm cmd/tree --depth 2 .
printf 'wasm wasm portable cli\n' | moon run --target wasm cmd/pulse --top 3
```

## Run With Wasmtime

Build the WASIp1 modules:

```sh
moon build --target wasm cmd/cow cmd/tree cmd/pulse
```

Then run a built module with explicit preopened paths:

```sh
wasmtime run --dir .::. _build/wasm/debug/build/cmd/tree/tree.wasm --depth 2 .
```

Use `scripts/smoke.sh` to exercise all commands through `moon run --target wasm`
and direct `wasmtime` when `wasmtime` is installed.
