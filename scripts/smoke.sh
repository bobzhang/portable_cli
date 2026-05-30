#!/bin/sh
set -eu

moon check --target wasm
moon test --target wasm
moon cram test tests/cram

tmp=".tmp/portable-cli-smoke"
rm -rf "$tmp"
mkdir -p "$tmp/src/nested"
printf 'alpha\n' > "$tmp/src/a.txt"
printf 'beta\n' > "$tmp/src/nested/b.txt"
printf '# Smoke\n\nPortable repo pack.\n' > "$tmp/README.md"
printf '<section><p>File <em>input</em></p></section>\n' > "$tmp/input.html"
printf 'MoonBit wasm wasm portable CLI\nMoonBit CLI\n' > "$tmp/input.txt"
printf '{"items":[{"name":"moon"},{"name":"wasm"}],"ok":true}\n' > "$tmp/data.json"

moon run --target wasm cmd/cow -- --width 24 portable wasm cli >/tmp/portable-cli-cow.out
grep 'portable wasm cli' /tmp/portable-cli-cow.out >/dev/null

moon run --target wasm cmd/htmlfmt -- --file "$tmp/input.html" --output "$tmp/formatted.html"
grep '<p>File <em>input</em></p>' "$tmp/formatted.html" >/dev/null

moon run --target wasm cmd/jqlet -- --file "$tmp/data.json" --get 'items[1].name' --raw >/tmp/portable-cli-jqlet.out
grep 'wasm' /tmp/portable-cli-jqlet.out >/dev/null
moon run --target wasm cmd/jqlet -- --file "$tmp/data.json" --get ok --compact --output "$tmp/ok.json"
grep 'true' "$tmp/ok.json" >/dev/null

moon run --target wasm cmd/repopack -- --max-files 8 --max-chars 80 --output "$tmp/repo.md" "$tmp"
grep 'Portable repo pack' "$tmp/repo.md" >/dev/null

moon run --target wasm cmd/tree -- --depth 2 "$tmp/src" >/tmp/portable-cli-tree.out
grep 'nested/' /tmp/portable-cli-tree.out >/dev/null

moon run --target wasm cmd/pulse -- --file "$tmp/input.txt" --top 3 --width 12 >/tmp/portable-cli-pulse.out
grep 'wasm' /tmp/portable-cli-pulse.out >/dev/null

moon build --target wasm cmd/cow cmd/htmlfmt cmd/jqlet cmd/repopack cmd/tree cmd/pulse

if command -v wasmtime >/dev/null 2>&1; then
  moonbit_runtime="wasm/moonbit-sys-unstable.wat"
  cow_wasm=$(find _build/wasm/debug/build -path '*cmd/cow/*.wasm' | head -n 1)
  htmlfmt_wasm=$(find _build/wasm/debug/build -path '*cmd/htmlfmt/*.wasm' | head -n 1)
  jqlet_wasm=$(find _build/wasm/debug/build -path '*cmd/jqlet/*.wasm' | head -n 1)
  repopack_wasm=$(find _build/wasm/debug/build -path '*cmd/repopack/*.wasm' | head -n 1)
  tree_wasm=$(find _build/wasm/debug/build -path '*cmd/tree/*.wasm' | head -n 1)
  pulse_wasm=$(find _build/wasm/debug/build -path '*cmd/pulse/*.wasm' | head -n 1)

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$cow_wasm" --width 24 portable wasm cli >/tmp/portable-cli-cow-wasmtime.out
  grep 'portable wasm cli' /tmp/portable-cli-cow-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$htmlfmt_wasm" --file "$tmp/input.html" --output "$tmp/formatted-wasmtime.html"
  grep '<p>File <em>input</em></p>' "$tmp/formatted-wasmtime.html" >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$jqlet_wasm" --file "$tmp/data.json" --get 'items[1].name' --raw >/tmp/portable-cli-jqlet-wasmtime.out
  grep 'wasm' /tmp/portable-cli-jqlet-wasmtime.out >/dev/null
  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$jqlet_wasm" --file "$tmp/data.json" --get ok --compact --output "$tmp/ok-wasmtime.json"
  grep 'true' "$tmp/ok-wasmtime.json" >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$repopack_wasm" --max-files 8 --max-chars 80 --output "$tmp/repo-wasmtime.md" "$tmp"
  grep 'Portable repo pack' "$tmp/repo-wasmtime.md" >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$tree_wasm" --depth 2 "$tmp/src" >/tmp/portable-cli-tree-wasmtime.out
  grep 'nested/' /tmp/portable-cli-tree-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$pulse_wasm" --file "$tmp/input.txt" --top 3 --width 12 >/tmp/portable-cli-pulse-wasmtime.out
  grep 'wasm' /tmp/portable-cli-pulse-wasmtime.out >/dev/null
fi

rm -rf "$tmp"
