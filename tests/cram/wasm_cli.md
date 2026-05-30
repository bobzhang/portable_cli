# WASM CLI Examples

These examples are executable documentation for the portable CLIs. Moon Cram
checks the transcripts, and every command is run through `moon run --target wasm`
so the tests cover the `miniio` WASIp1 path instead of native executables.

Use `--` before command arguments when a CLI option starts with `-`; otherwise
Moon's runner may consume flags such as `--help`.

## Command Index

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/main
portable_cli commands: cmd/cow, cmd/htmlfmt, cmd/jqlet, cmd/tree, cmd/pulse
```

## Cow Help

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/cow -- --help | sed -n '1,12p'
Usage: cow [options] [message...]

Wrap text in a speech bubble and render a small ASCII cow.

Arguments:
  message...  message words; stdin is used when omitted

Options:
  -h, --help           Show help information.
  -V, --version        Show version information.
  -t, --think          use a thought bubble tail
  -w, --width <width>  bubble width [env: COW_WIDTH] [default: 40]
```

## Cow From Arguments

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/cow -- --width 18 portable wasm cli
 ___________________
< portable wasm cli >
 -------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

## Cow From Stdin And Env

`COW_WIDTH` is an `@argparse` environment default, while explicit flags still
control the tail, eyes, and tongue.

```mooncram
$ printf 'moonbit cram docs\n' | COW_WIDTH=12 moon -C "$TESTDIR/../.." run --target wasm cmd/cow -- --think --eyes ^^ --tongue U
 ______________
/ moonbit cram \
\ docs         /
 --------------
        o   ^__^
         o  (^^)\_______
            (__)\       )\/\
             U  ||----w |
                ||     ||
```

## Htmlfmt Fragment

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- '<article><p>Hello <b>MoonBit</b></p></article>'
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Htmlfmt Compact Stdin

```mooncram
$ printf '<p class=demo>Hello <b>MoonBit</b></p>\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/htmlfmt -- --compact
<p class="demo">Hello <b>MoonBit</b></p>
```

## Htmlfmt Output File

```mooncram
$ root="$TESTDIR/../.."; in=".tmp/moon-cram-htmlfmt.html"; out=".tmp/moon-cram-htmlfmt-out.html"; printf '<section><p>File <em>input</em></p></section>\n' > "$root/$in"; moon -C "$root" run --target wasm cmd/htmlfmt -- --file "$in" --output "$out"; cat "$root/$out"; rm -f "$root/$in" "$root/$out"
<section>
  <p>File <em>input</em></p>
</section>
```

## Jqlet Path Extraction

```mooncram
$ printf '{"items":[{"name":"moon"},{"name":"wasm"}],"ok":true}\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --get 'items[1].name' --raw
wasm
```

## Jqlet Pretty JSON

```mooncram
$ printf '{"items":[{"name":"moon","score":2}],"ok":true}\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --indent 4
{
    "items": [
        {
            "name": "moon",
            "score": 2
        }
    ],
    "ok": true
}
```

## Jqlet Output File

```mooncram
$ root="$TESTDIR/../.."; out=".tmp/moon-cram-jqlet.json"; rm -f "$root/$out"; printf '{"ok":true}\n' | moon -C "$root" run --target wasm cmd/jqlet -- --get ok --compact --output "$out"; cat "$root/$out"; rm -f "$root/$out"
true
```

## Tree Default Filtering

```mooncram
$ root="$TESTDIR/../.."; tmp=".tmp/moon-cram-tree"; rm -rf "$root/$tmp"; mkdir -p "$root/$tmp/src" "$root/$tmp/empty" "$root/$tmp/.config"; printf 'hello\n' > "$root/$tmp/README.md"; printf 'main\n' > "$root/$tmp/src/main.mbt"; printf 'secret\n' > "$root/$tmp/.config/settings"; moon -C "$root" run --target wasm cmd/tree -- --depth 1 "$tmp"; rm -rf "$root/$tmp"
.tmp/moon-cram-tree/
|-- src/
|-- empty/
`-- README.md
```

## Tree Hidden Entries

```mooncram
$ root="$TESTDIR/../.."; tmp=".tmp/moon-cram-tree"; rm -rf "$root/$tmp"; mkdir -p "$root/$tmp/src" "$root/$tmp/empty" "$root/$tmp/.config"; printf 'hello\n' > "$root/$tmp/README.md"; printf 'main\n' > "$root/$tmp/src/main.mbt"; printf 'secret\n' > "$root/$tmp/.config/settings"; moon -C "$root" run --target wasm cmd/tree -- --depth 2 --all "$tmp"; rm -rf "$root/$tmp"
.tmp/moon-cram-tree/
|-- src/
|   `-- main.mbt
|-- empty/
|-- .config/
|   `-- settings
`-- README.md
```

## Tree Directories Only

```mooncram
$ root="$TESTDIR/../.."; tmp=".tmp/moon-cram-tree"; rm -rf "$root/$tmp"; mkdir -p "$root/$tmp/src" "$root/$tmp/empty" "$root/$tmp/.config"; printf 'hello\n' > "$root/$tmp/README.md"; printf 'main\n' > "$root/$tmp/src/main.mbt"; printf 'secret\n' > "$root/$tmp/.config/settings"; moon -C "$root" run --target wasm cmd/tree -- --dirs-only --all "$tmp"; rm -rf "$root/$tmp"
.tmp/moon-cram-tree/
|-- src/
|-- empty/
`-- .config/
```

## Pulse From Stdin

```mooncram
$ printf 'Moon moon WASM\nportable CLI moon\n' | moon -C "$TESTDIR/../.." run --target wasm cmd/pulse -- --top 3 --width 12
chars: 33
lines: 2
words: 6
unique: 4

top words:
moon              3 ############
cli               1 ####
wasm              1 ####
```

## Pulse From File

```mooncram
$ root="$TESTDIR/../.."; file=".tmp/moon-cram-pulse.txt"; printf 'Moon moon WASM\nMoon CLI wasm\n' > "$root/$file"; moon -C "$root" run --target wasm cmd/pulse -- --file "$file" --preserve-case --top 5 --width 10; rm -f "$root/$file"
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

## Argparse Error

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/jqlet -- --bad > unknown.out 2> unknown.err; sed -n '1,4p' unknown.err; test ! -s unknown.out
error: unexpected argument '--bad' found

Usage: jqlet [options]

```
