# Htmlfmt CLI

`cmd/htmlfmt` is a portable HTML formatter backed by `bobzhang/html_parser`.
These examples run the Wasm target through `moon run --target wasm`, so the
transcripts document the command line contract and verify the `miniio` WASIp1
path.

The examples use checked HTML fixtures under `tests/cram/fixtures/html`. Use
`--file` and `--output` when an agent needs to format guest-visible files
without moving data through the conversation.

## CLI Flags

- `html...`: inline HTML fragment words. When omitted, `htmlfmt` reads stdin.
- `-f, --file <file>`: read HTML from a guest-visible file.
- `-o, --output <output>`: write formatted HTML to a guest-visible file.
- `-c, --compact`: write compact normalized HTML instead of pretty HTML.
- `-d, --document`: parse the input as a full HTML document. Default: fragment mode.
- `--sanitize`: apply the default sanitizer before formatting.
- `--strict`: fail on the first parse error.
- `-i, --indent <indent>`: set pretty-print indentation. Default: `2`.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

## Format A Fragment

Fragment mode is the default. The formatter preserves inline text flow while
putting block-level structure on separate lines.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --file tests/cram/fixtures/html/fragment.html
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Compact Output

Use `--compact` when the caller wants normalized HTML without pretty-print
whitespace.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --file tests/cram/fixtures/html/compact.html --compact
<p class="demo">Hello <b>MoonBit</b></p>
```

## Full Document Mode

Use `--document` when the input is a full HTML document instead of a fragment.
The parser normalizes the doctype and inserts missing document structure.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --file tests/cram/fixtures/html/document.html --document
<!DOCTYPE html>
<html>
  <head></head>
  <body>
    <p>Hi</p>
  </body>
</html>
```

## Sanitized Formatting

Use `--sanitize` before formatting untrusted HTML. The default sanitizer removes
script content and unsafe event attributes before serialization.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --file tests/cram/fixtures/html/unsafe.html --sanitize
<p>Hello <b>MoonBit</b></p>
```

## File Input And Output

The portable I/O surface can read and write paths visible to the Wasm guest.
This example formats a checked fixture and writes the generated output under the
repository `.tmp` directory.

```mooncram
$ root="$TESTDIR/../.."; out=".tmp/moon-cram-htmlfmt-out.html"; rm -f "$root/$out"; moon -C "$root" run --target wasm cmd/htmlfmt -- --file tests/cram/fixtures/html/fragment.html --output "$out"; cat "$root/$out"; rm -f "$root/$out"
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```
