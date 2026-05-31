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
printf 'id,name,score\n1,Ada,9.5\n2,Bob,7\n' > "$tmp/data.csv"
printf 'OPENAI_API_KEY=sk-test-abcdefghijklmnopqrstuvwxyz1234567890\n' > "$tmp/secrets.env"
printf '%s\n' '%PDF-1.4' '1 0 obj' '<< /Type /Catalog /Pages 2 0 R /OpenAction 3 0 R >>' 'endobj' '2 0 obj' '<< /Type /Pages /Count 1 /Kids [3 0 R] >>' 'endobj' '3 0 obj' '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>' 'endobj' 'xref' '0 4' '0000000000 65535 f' 'trailer' '<< /Root 1 0 R /Size 4 >>' 'startxref' '187' '%%EOF' > "$tmp/input.pdf"

moon run --target wasm cmd/cow -- --width 24 portable wasm cli >/tmp/portable-cli-cow.out
grep 'portable wasm cli' /tmp/portable-cli-cow.out >/dev/null

moon run --target wasm cmd/datascout -- --file "$tmp/data.csv" >/tmp/portable-cli-datascout.out
grep 'Data Scout' /tmp/portable-cli-datascout.out >/dev/null
grep 'score | number' /tmp/portable-cli-datascout.out >/dev/null

moon run --target wasm cmd/htmlfmt -- --file "$tmp/input.html" --output "$tmp/formatted.html"
grep '<p>File <em>input</em></p>' "$tmp/formatted.html" >/dev/null
moon run --target wasm cmd/htmlfmt -- --inspect --file "$tmp/input.html" >/tmp/portable-cli-htmlfmt-inspect.out
grep 'HTML Inspect' /tmp/portable-cli-htmlfmt-inspect.out >/dev/null

moon run --target wasm cmd/jqlet -- --file "$tmp/data.json" --get 'items[1].name' --raw >/tmp/portable-cli-jqlet.out
grep 'wasm' /tmp/portable-cli-jqlet.out >/dev/null
moon run --target wasm cmd/jqlet -- --file "$tmp/data.json" --get ok --compact --output "$tmp/ok.json"
grep 'true' "$tmp/ok.json" >/dev/null

moon run --target wasm cmd/pdfskill -- doctor "$tmp/input.pdf" >/tmp/portable-cli-pdfskill.out
grep 'info risk: active-content' /tmp/portable-cli-pdfskill.out >/dev/null

moon run --target wasm cmd/repopack -- --max-files 8 --max-chars 80 --output "$tmp/repo.md" "$tmp"
grep 'Portable repo pack' "$tmp/repo.md" >/dev/null
moon run --target wasm cmd/repopack -- --stats --budget-chars 80 --max-files 8 --max-chars 80 --output "$tmp/repo-budget.md" "$tmp"
grep 'Extension Summary' "$tmp/repo-budget.md" >/dev/null
moon run --target wasm cmd/repopack -- --redact-secrets --ext env,md,txt --max-files 8 --max-chars 120 --output "$tmp/repo-redacted.md" "$tmp"
grep -F '[REDACTED:api-key]' "$tmp/repo-redacted.md" >/dev/null

moon run --target wasm cmd/secretscan -- "$tmp" >/tmp/portable-cli-secretscan.out
grep 'openai-style api key' /tmp/portable-cli-secretscan.out >/dev/null

moon run --target wasm cmd/tree -- --depth 2 "$tmp/src" >/tmp/portable-cli-tree.out
grep 'nested/' /tmp/portable-cli-tree.out >/dev/null

moon run --target wasm cmd/pulse -- --file "$tmp/input.txt" --top 3 --width 12 >/tmp/portable-cli-pulse.out
grep 'wasm' /tmp/portable-cli-pulse.out >/dev/null

moon build --target wasm cmd/cow cmd/datascout cmd/htmlfmt cmd/jqlet cmd/pdfskill cmd/repopack cmd/secretscan cmd/tree cmd/pulse

if command -v wasmtime >/dev/null 2>&1; then
  moonbit_runtime="wasm/moonbit-sys-unstable.wat"
  cow_wasm=$(find _build/wasm/debug/build -path '*cmd/cow/*.wasm' | head -n 1)
  datascout_wasm=$(find _build/wasm/debug/build -path '*cmd/datascout/*.wasm' | head -n 1)
  htmlfmt_wasm=$(find _build/wasm/debug/build -path '*cmd/htmlfmt/*.wasm' | head -n 1)
  jqlet_wasm=$(find _build/wasm/debug/build -path '*cmd/jqlet/*.wasm' | head -n 1)
  pdfskill_wasm=$(find _build/wasm/debug/build -path '*cmd/pdfskill/*.wasm' | head -n 1)
  repopack_wasm=$(find _build/wasm/debug/build -path '*cmd/repopack/*.wasm' | head -n 1)
  secretscan_wasm=$(find _build/wasm/debug/build -path '*cmd/secretscan/*.wasm' | head -n 1)
  tree_wasm=$(find _build/wasm/debug/build -path '*cmd/tree/*.wasm' | head -n 1)
  pulse_wasm=$(find _build/wasm/debug/build -path '*cmd/pulse/*.wasm' | head -n 1)

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$cow_wasm" --width 24 portable wasm cli >/tmp/portable-cli-cow-wasmtime.out
  grep 'portable wasm cli' /tmp/portable-cli-cow-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$datascout_wasm" --file "$tmp/data.csv" >/tmp/portable-cli-datascout-wasmtime.out
  grep 'Data Scout' /tmp/portable-cli-datascout-wasmtime.out >/dev/null
  grep 'score | number' /tmp/portable-cli-datascout-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$htmlfmt_wasm" --file "$tmp/input.html" --output "$tmp/formatted-wasmtime.html"
  grep '<p>File <em>input</em></p>' "$tmp/formatted-wasmtime.html" >/dev/null
  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$htmlfmt_wasm" --inspect --file "$tmp/input.html" >/tmp/portable-cli-htmlfmt-inspect-wasmtime.out
  grep 'HTML Inspect' /tmp/portable-cli-htmlfmt-inspect-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$jqlet_wasm" --file "$tmp/data.json" --get 'items[1].name' --raw >/tmp/portable-cli-jqlet-wasmtime.out
  grep 'wasm' /tmp/portable-cli-jqlet-wasmtime.out >/dev/null
  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$jqlet_wasm" --file "$tmp/data.json" --get ok --compact --output "$tmp/ok-wasmtime.json"
  grep 'true' "$tmp/ok-wasmtime.json" >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$pdfskill_wasm" doctor "$tmp/input.pdf" >/tmp/portable-cli-pdfskill-wasmtime.out
  grep 'info risk: active-content' /tmp/portable-cli-pdfskill-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$repopack_wasm" --max-files 8 --max-chars 80 --output "$tmp/repo-wasmtime.md" "$tmp"
  grep 'Portable repo pack' "$tmp/repo-wasmtime.md" >/dev/null
  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$repopack_wasm" --stats --budget-chars 80 --max-files 8 --max-chars 80 --output "$tmp/repo-budget-wasmtime.md" "$tmp"
  grep 'Extension Summary' "$tmp/repo-budget-wasmtime.md" >/dev/null
  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$repopack_wasm" --redact-secrets --ext env,md,txt --max-files 8 --max-chars 120 --output "$tmp/repo-redacted-wasmtime.md" "$tmp"
  grep -F '[REDACTED:api-key]' "$tmp/repo-redacted-wasmtime.md" >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$secretscan_wasm" "$tmp" >/tmp/portable-cli-secretscan-wasmtime.out
  grep 'openai-style api key' /tmp/portable-cli-secretscan-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$tree_wasm" --depth 2 "$tmp/src" >/tmp/portable-cli-tree-wasmtime.out
  grep 'nested/' /tmp/portable-cli-tree-wasmtime.out >/dev/null

  wasmtime run --dir .::. --preload __moonbit_sys_unstable="$moonbit_runtime" "$pulse_wasm" --file "$tmp/input.txt" --top 3 --width 12 >/tmp/portable-cli-pulse-wasmtime.out
  grep 'wasm' /tmp/portable-cli-pulse-wasmtime.out >/dev/null
fi

rm -rf "$tmp"
