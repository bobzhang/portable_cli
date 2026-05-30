# Tree CLI

`cmd/tree` renders deterministic directory trees over paths visible to the Wasm
guest. It is intentionally small: the command sorts entries, hides dotfiles by
default, and formats output for quick agent inspection.

## CLI Flags

- `path`: root directory to render. Default: `.`.
- `-a, --all`: include hidden entries.
- `-d, --dirs-only`: show directories only.
- `-L, --depth <depth>`: maximum recursion depth. `TREE_DEPTH` can provide the default.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

## Default Filtering

By default, hidden entries are omitted. The fixture contains `.config/` and a
hidden `.gitkeep` marker, neither of which appears here.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/tree -- --depth 2 tests/cram/fixtures/tree-demo
tests/cram/fixtures/tree-demo/
|-- code/
|   `-- main.txt
|-- empty/
`-- README.md
```

## Hidden Entries

Use `--all` when hidden directories and files are useful context.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/tree -- --depth 2 --all tests/cram/fixtures/tree-demo
tests/cram/fixtures/tree-demo/
|-- code/
|   `-- main.txt
|-- empty/
|   `-- .gitkeep
|-- .config/
|   `-- settings
`-- README.md
```

## Directories Only

`--dirs-only` is useful for high-level project layout overviews.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/tree -- --dirs-only --all tests/cram/fixtures/tree-demo
tests/cram/fixtures/tree-demo/
|-- code/
|-- empty/
`-- .config/
```
