# Portable PDF Skill CLI

`cmd/pdfskill` is a lightweight PDF triage tool for portable agent skills. It
uses `bobzhang/pdflite/reader` for header and `startxref` parsing, then reports
byte-level object and risk signals that are useful before handing a file to a
heavier PDF renderer or extractor.

The PDF examples use checked fixtures under `tests/cram/fixtures`. Keeping PDFs
as fixtures makes the documentation readable and keeps expected object offsets
stable. `pandoc-report.pdf` is generated from Markdown with Pandoc and Tectonic:

```sh
pandoc tests/cram/fixtures/pandoc-report.md \
  --pdf-engine=tectonic \
  -o tests/cram/fixtures/pandoc-report.pdf
```

The smaller `active-action.pdf` is hand-authored so the active-content risk
case has tiny, stable object offsets.

## CLI Flags

Top-level:

- `brief`: write an agent-readable Markdown or JSON triage report.
- `doctor`: run quick structural checks and print pass/warn lines.
- `map`: list indirect object candidates with byte offsets.
- `-h, --help`, `-V, --version`: standard generated `@argparse` help/version flags.

`brief`:

- `input`: input PDF path.
- `--json`: write compact JSON instead of Markdown.
- `-o, --output <output>`: write the report to a guest-visible file.

`doctor`:

- `input`: input PDF path.

`map`:

- `input`: input PDF path.
- `--limit <limit>`: maximum object candidates to print. Default: `40`.

## Pandoc-Generated PDF

The Pandoc fixture represents a normal documentation PDF. `doctor` should route
it as low risk while still reporting the real PDF version, `startxref`, EOF
marker, and object count.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/pandoc-report.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- doctor "$fixture"
pdfskill doctor: tests/cram/fixtures/pandoc-report.pdf
ok header: PDF 1.5
ok startxref: 18661
ok eof: 1
ok objects: 18
info risk: low
```

## Doctor Summary

`doctor` is also useful for suspicious PDFs. This fixture intentionally contains
`/OpenAction`, so the risk label is `active-content`.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- doctor "$fixture"
pdfskill doctor: tests/cram/fixtures/active-action.pdf
ok header: PDF 1.4
ok startxref: 187
ok eof: 1
ok objects: 3
info risk: active-content
```

## Agent Brief

`brief` writes Markdown that can be pasted into an agent conversation. The
fixture intentionally contains `/OpenAction`, so the risk label is
`active-content`.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- brief "$fixture"
# PDF Skill Brief

- path: `tests/cram/fixtures/active-action.pdf`
- version: 1.4
- bytes: 286
- startxref: 187
- eof markers: 1
- object candidates: 3
- page candidates: 1
- stream candidates: 0
- xref tokens: 2
- encrypted: false
- javascript names: 0
- active action names: 1
- embedded file names: 0
- acroform: false
- xfa: false
- image names: 0
- object streams: 0
- linearized: false
- risk: active-content

## Agent Notes

- This is byte-level triage, not page rendering or full semantic extraction.
- Escalate to a renderer/parser when signatures, forms, layout, or attachments matter.
```

## JSON Brief

Use `--json` when another tool should consume the result. The output is compact
and stable enough for simple shell checks.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- brief --json "$fixture"
{"acroform":false,"active_actions":1,"bytes":286,"embedded_files":0,"encrypted":false,"eof_markers":1,"images":0,"javascript":0,"linearized":false,"object_candidates":3,"object_streams":0,"page_candidates":1,"path":"tests/cram/fixtures/active-action.pdf","risk":"active-content","startxref":187,"stream_candidates":0,"version":"1.4","xfa":false,"xref_tokens":2}
```

## Object Map

`map` lists indirect object candidates and byte offsets. This is useful when
debugging broken xrefs or deciding which byte ranges deserve closer inspection.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- map --limit 3 "$fixture"
# PDF Object Map

- path: `tests/cram/fixtures/active-action.pdf`
- listed: 3

| object | generation | offset |
|---:|---:|---:|
| 1 | 0 | 9 |
| 2 | 0 | 76 |
| 3 | 0 | 133 |
```

## Bundled Skill Artifact

The Codex skill commits the release Wasm artifact under
`skills/portable-pdf/assets`, so agents can run it with `moonrun` without a
MoonBit build step.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; (cd "$root" && moonrun skills/portable-pdf/assets/pdfskill.wasm doctor "$fixture")
pdfskill doctor: tests/cram/fixtures/active-action.pdf
ok header: PDF 1.4
ok startxref: 187
ok eof: 1
ok objects: 3
info risk: active-content
```
