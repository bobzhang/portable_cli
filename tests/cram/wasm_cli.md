# Portable Wasm CLI Documentation

This directory is both documentation and an executable test suite. Moon Cram
checks every `mooncram` transcript, so each command page documents real
`moon run --target wasm` behavior over the `miniio` WASIp1 path.

Use `--` before command arguments when a CLI option starts with `-`; otherwise
Moon's runner may consume flags such as `--help`.

## Command Index

```mooncram
$ moon -C "$TESTDIR/../.." run --target wasm cmd/main
portable_cli commands: cmd/cow, cmd/datascout, cmd/diffskill, cmd/htmlfmt, cmd/jqlet, cmd/mdskill, cmd/pdfskill, cmd/repopack, cmd/secretscan, cmd/svgcheck, cmd/tomlskill, cmd/tree, cmd/pulse
```

## Command Pages

- [cow.md](cow.md): speech bubbles and ASCII cow rendering.
- [datascout.md](datascout.md): bounded schema and sample reports for CSV/TSV-like data.
- [diffskill.md](diffskill.md): review-focused summaries for unified diffs.
- [htmlfmt.md](htmlfmt.md): HTML formatting, compacting, document mode, and sanitization.
- [jqlet.md](jqlet.md): JSON formatting and simple path extraction.
- [mdskill.md](mdskill.md): Markdown outline, link, task, code fence, and issue inventory.
- [pdfskill.md](pdfskill.md): portable PDF triage and bundled PDF skill usage.
- [pulse.md](pulse.md): text statistics and compact word histograms.
- [repopack.md](repopack.md): repository context packing and bundled repopack skill usage.
- [secretscan.md](secretscan.md): redacted secret scanning before sharing context.
- [svgcheck.md](svgcheck.md): SVG structure and risk signal inspection.
- [tomlskill.md](tomlskill.md): TOML-style config inspection, formatting, and value extraction.
- [tree.md](tree.md): deterministic directory tree rendering.
