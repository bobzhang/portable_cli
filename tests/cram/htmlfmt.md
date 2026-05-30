# Htmlfmt CLI

`cmd/htmlfmt` is a portable HTML formatter backed by `bobzhang/html_parser`.
These examples run the Wasm target through `moon run --target wasm`, so the
transcripts document the command line contract and verify the `miniio` WASIp1
path.

Most examples pass HTML directly or through stdin. Use `--file` and `--output`
when an agent needs to format guest-visible files without moving data through
the conversation.

## Format A Fragment

Fragment mode is the default. The formatter preserves inline text flow while
putting block-level structure on separate lines.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- '<article><p>Hello <b>MoonBit</b></p></article>'
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Compact Output

Use `--compact` when the caller wants normalized HTML without pretty-print
whitespace.

```mooncram
$ printf '<p class=demo>Hello <b>MoonBit</b></p>\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --compact
<p class="demo">Hello <b>MoonBit</b></p>
```

## Full Document Mode

Use `--document` when the input is a full HTML document instead of a fragment.
The parser normalizes the doctype and inserts missing document structure.

```mooncram
$ printf '<!doctype html><html><body><p>Hi</p></body></html>\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --document
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
$ printf '<main><script>alert(1)</script><p onclick=run()>Hello <b>MoonBit</b></p></main>\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --sanitize
<p>Hello <b>MoonBit</b></p>
```

## File Input And Output

The portable I/O surface can read and write paths visible to the Wasm guest.
This example writes a small source file under the repository `.tmp` directory,
formats it through the Wasm command, then prints the generated output.

```mooncram
$ root="$TESTDIR/../.."; in=".tmp/moon-cram-htmlfmt.html"; out=".tmp/moon-cram-htmlfmt-out.html"; printf '<section><p>File <em>input</em></p></section>\n' > "$root/$in"; moon -C "$root" run --target wasm cmd/htmlfmt -- --file "$in" --output "$out"; cat "$root/$out"; rm -f "$root/$in" "$root/$out"
<section>
  <p>File <em>input</em></p>
</section>
```
