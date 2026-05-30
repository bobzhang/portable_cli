# Repopack CLI

`cmd/repopack` packs guest-visible text files into deterministic Markdown
context. It is designed for portable agent handoffs where stable ordering,
small output, and conservative default ignores matter more than full native
Git-aware repository traversal.

## CLI Flags

- `path`: root file or directory to pack. Default: `.`.
- `--hidden`: include hidden entries that are skipped by default.
- `--no-default-ignore`: disable built-in ignores such as `.git`, `_build`, and `node_modules`.
- `--all-files`: try every readable text file instead of filtering by extension.
- `-e, --ext <ext>`: comma-separated extension allowlist, for example `mbt,md,json`.
- `--max-files <max-files>`: cap included files. Default: `64`.
- `--max-chars <max-chars>`: cap characters per file after read. Default: `8000`.
- `-o, --output <output>`: write Markdown to a guest-visible file.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

## Markdown Bundle

The fixture includes a Markdown file, a small text source file, a hidden file,
and a `node_modules` directory. Default ignores keep the generated bundle
focused.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/repopack -- --max-chars 40 tests/cram/fixtures/repopack-demo
# Repo Pack

- root: `tests/cram/fixtures/repopack-demo`
- files: 2
- max chars per file: 40

## Included Files

- `tests/cram/fixtures/repopack-demo/README.md` - 23 chars
- `tests/cram/fixtures/repopack-demo/code/main.txt` - 26 chars

## File Contents

### `tests/cram/fixtures/repopack-demo/README.md`

~~~~markdown
# Demo

Hello MoonBit.
~~~~

### `tests/cram/fixtures/repopack-demo/code/main.txt`

~~~~text
fn main { println("hi") }
~~~~
```

## Bundled Skill Artifact

The `portable-repopack` skill commits a release Wasm artifact, so an agent can
run it through `moonrun` without a MoonBit build step.

```mooncram
$ root="$TESTDIR/../.."; (cd "$root" && moonrun skills/portable-repopack/assets/repopack.wasm --max-files 4 --max-chars 80 tests/cram/fixtures/repopack-demo)
# Repo Pack

- root: `tests/cram/fixtures/repopack-demo`
- files: 2
- max chars per file: 80

## Included Files

- `tests/cram/fixtures/repopack-demo/README.md` - 23 chars
- `tests/cram/fixtures/repopack-demo/code/main.txt` - 26 chars

## File Contents

### `tests/cram/fixtures/repopack-demo/README.md`

~~~~markdown
# Demo

Hello MoonBit.
~~~~

### `tests/cram/fixtures/repopack-demo/code/main.txt`

~~~~text
fn main { println("hi") }
~~~~
```
