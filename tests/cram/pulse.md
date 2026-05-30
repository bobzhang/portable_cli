# Pulse CLI

`cmd/pulse` reads text from a file or stdin and prints a compact word histogram.
It is useful as a portable agent primitive for quickly summarizing plain text
without depending on host shell utilities.

## CLI Flags

- `-f, --file <file>`: read text from a guest-visible file. Without it, read stdin.
- `--preserve-case`: keep original word case instead of lowercasing.
- `-n, --top <top>`: number of words to show. Default: `8`.
- `-w, --width <width>`: maximum bar width. Default: `24`.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

## Word Histogram

The default mode lowercases words before counting.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/pulse -- --file tests/cram/fixtures/text/pulse.txt --top 3 --width 12
chars: 33
lines: 2
words: 6
unique: 4

top words:
moon              3 ############
cli               1 ####
wasm              1 ####
```

## Preserve Case

Use `--preserve-case` when uppercase tokens are semantically meaningful.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/pulse -- --file tests/cram/fixtures/text/pulse-case.txt --preserve-case --top 5 --width 10
chars: 29
lines: 2
words: 6
unique: 5

top words:
Moon              2 ##########
CLI               1 #####
WASM              1 #####
moon              1 #####
wasm              1 #####
```
