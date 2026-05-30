# Jqlet CLI

`cmd/jqlet` is a deliberately small JSON formatter and path extractor. It is not
a full `jq` replacement; it covers the common portable-skill cases of pretty
printing JSON, compacting it, and extracting simple dotted paths from
guest-visible files or stdin.

## CLI Flags

- `-f, --file <file>`: read JSON from a guest-visible file. Without it, read stdin.
- `-g, --get <path>`: extract a simple path such as `user.name` or `items[0].id`.
- `-r, --raw`: print selected JSON strings without surrounding JSON quotes.
- `-c, --compact`: write compact JSON.
- `-i, --indent <indent>`: set pretty-print indentation. Default: `2`.
- `-o, --output <output>`: write output to a guest-visible file.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

## Path Extraction

The fixture lives at `tests/cram/fixtures/json/items.json`, so the command shows
normal file input instead of embedding JSON in a shell one-liner.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --file tests/cram/fixtures/json/items.json --get 'items[1].name' --raw
wasm
```

## Pretty JSON

Pretty printing is the default output mode. `--indent` controls the number of
spaces used for nested structures.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --file tests/cram/fixtures/json/items.json --indent 4
{
    "items": [
        {
            "name": "moon",
            "score": 2
        },
        {
            "name": "wasm",
            "score": 3
        }
    ],
    "ok": true
}
```

## Output File

Use `--output` when another step should read the extracted or formatted JSON.

```mooncram
$ root="$TESTDIR/../.."; out=".tmp/moon-cram-jqlet.json"; rm -f "$root/$out"; moon -C "$root" run --target wasm cmd/jqlet -- --file tests/cram/fixtures/json/items.json --get ok --compact --output "$out"; cat "$root/$out"; rm -f "$root/$out"
true
```

## Argparse Error

Unknown flags fail through the shared `@argparse` error path.

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --bad > unknown.out 2> unknown.err; sed -n '1,4p' unknown.err; test ! -s unknown.out
error: unexpected argument '--bad' found

Usage: jqlet [options]

```
