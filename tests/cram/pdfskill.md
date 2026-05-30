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
case has tiny, stable object offsets. `metadata-info.pdf` is also hand-authored
and keeps Info dictionary and XMP metadata fields stable.

## CLI Flags

Top-level:

- `brief`: write an agent-readable Markdown or JSON triage report.
- `doctor`: run quick structural checks and print pass/warn lines.
- `map`: list indirect object candidates with byte offsets.
- `objects`: parse and summarize indirect objects, dictionaries, and streams.
- `streams`: list PDF streams and optionally decode bounded previews.
- `metadata`: extract common Info dictionary fields and XMP metadata previews.
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

`objects`:

- `input`: input PDF path.
- `--json`: write compact JSON instead of Markdown.
- `--limit <limit>`: maximum matching objects to print. Default: `40`.
- `--contains <text>`: only include objects whose raw bytes or summary contain this text.

`streams`:

- `input`: input PDF path.
- `--json`: write compact JSON instead of Markdown.
- `--decode`: decode supported filters before previewing stream bytes.
- `--limit <limit>`: maximum streams to print. Default: `20`.
- `--max-bytes <max-bytes>`: maximum bytes to include in each preview. Default: `96`.

`metadata`:

- `input`: input PDF path.
- `--json`: write compact JSON instead of Markdown.
- `--max-bytes <max-bytes>`: maximum XMP bytes to include in the preview. Default: `160`.

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

## Object Inspector

`objects` parses indirect object bodies and reports the object kind, dictionary
`/Type`, `/Subtype`, stream filter, and declared stream length when those fields
are available. It remains bounded by `--limit`, so it is safe to use as a first
look at unfamiliar PDFs.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- objects --limit 5 "$fixture"
# PDF Objects

- path: `tests/cram/fixtures/active-action.pdf`
- listed: 3
- limit: 5

| object | generation | offset | kind | type | subtype | stream | length | filters | note |
|---:|---:|---:|---|---|---|---|---:|---|---|
| 1 | 0 | 9 | dict | /Catalog | - | false | - | - | - |
| 2 | 0 | 76 | dict | /Pages | - | false | - | - | - |
| 3 | 0 | 133 | dict | /Page | - | false | - | - | - |
```

The Pandoc fixture starts with compressed streams. `objects` can identify the
stream shape and filter without decoding stream bytes.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/pandoc-report.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- objects --limit 3 "$fixture"
# PDF Objects

- path: `tests/cram/fixtures/pandoc-report.pdf`
- listed: 3
- limit: 3

| object | generation | offset | kind | type | subtype | stream | length | filters | note |
|---:|---:|---:|---|---|---|---|---:|---|---|
| 14 | 0 | 15 | stream | - | - | true | 973 | /FlateDecode | - |
| 30 | 0 | 1057 | stream | - | - | true | 314 | /FlateDecode | - |
| 31 | 0 | 1440 | stream | - | - | true | 341 | /FlateDecode | - |
```

Use `--contains` to find likely object classes by raw token or parsed summary.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- objects --limit 4 --contains /Page "$fixture"
# PDF Objects

- path: `tests/cram/fixtures/active-action.pdf`
- listed: 3
- limit: 4
- contains: `/Page`

| object | generation | offset | kind | type | subtype | stream | length | filters | note |
|---:|---:|---:|---|---|---|---|---:|---|---|
| 1 | 0 | 9 | dict | /Catalog | - | false | - | - | - |
| 2 | 0 | 76 | dict | /Pages | - | false | - | - | - |
| 3 | 0 | 133 | dict | /Page | - | false | - | - | - |
```

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- objects --json --limit 2 "$fixture"
{"contains":null,"limit":2,"listed":2,"objects":[{"filters":"-","generation":0,"kind":"dict","length":"-","note":"-","object":1,"offset":9,"stream":false,"subtype":"-","type":"/Catalog"},{"filters":"-","generation":0,"kind":"dict","length":"-","note":"-","object":2,"offset":76,"stream":false,"subtype":"-","type":"/Pages"}],"path":"tests/cram/fixtures/active-action.pdf"}
```

## Stream Preview

`streams` focuses on stream payloads. Without `--decode`, previews show the raw
compressed bytes. With `--decode`, supported filters such as `/FlateDecode`,
`/ASCIIHexDecode`, `/ASCII85Decode`, `/RunLengthDecode`, and `/LZWDecode` are
decoded before producing a bounded, single-line preview.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/pandoc-report.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- streams --decode --max-bytes 80 --limit 2 "$fixture"
# PDF Streams

- path: `tests/cram/fixtures/pandoc-report.pdf`
- listed: 2
- limit: 2
- decode: true
- max bytes: 80

| object | generation | offset | raw start | raw bytes | length | filters | decoded bytes | status | preview |
|---:|---:|---:|---:|---:|---:|---|---:|---|---|
| 14 | 0 | 15 | 66 | 973 | 973 | /FlateDecode | 3212 | ok | ` q 1 0 0 1 72 719.99999 cm 0 g 0 G 0 G 0 g 0 G 0 g 0 G 0 g 0 G 0 g 0 G 0 g BT /F` |
| 30 | 0 | 1057 | 1108 | 314 | 314 | /FlateDecode | 553 | ok | `/CIDInit /ProcSet findresource begin.12 dict begin.begincmap./CMapName /IHAIZV+L` |
```

PDFs without streams produce an empty table instead of failing.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/active-action.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- streams --limit 3 "$fixture"
# PDF Streams

- path: `tests/cram/fixtures/active-action.pdf`
- listed: 0
- limit: 3
- decode: false
- max bytes: 96

| object | generation | offset | raw start | raw bytes | length | filters | decoded bytes | status | preview |
|---:|---:|---:|---:|---:|---:|---|---:|---|---|
```

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/pandoc-report.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- streams --json --decode --max-bytes 32 --limit 1 "$fixture"
{"decode":true,"limit":1,"listed":1,"max_bytes":32,"path":"tests/cram/fixtures/pandoc-report.pdf","streams":[{"decoded_bytes":"3212","decode_status":"ok","filters":"/FlateDecode","generation":0,"length":"973","object":14,"offset":15,"preview":" q 1 0 0 1 72 719.99999 cm 0 g 0","raw_bytes":973,"raw_start":66,"subtype":"-","type":"-"}]}
```

## Metadata Extraction

`metadata` extracts common Info dictionary fields from parsed objects and detects
XMP metadata streams. The command is intentionally lightweight: it reports the
fields it can prove from object dictionaries without requiring a full PDF object
graph.

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/metadata-info.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- metadata "$fixture"
# PDF Metadata

- path: `tests/cram/fixtures/metadata-info.pdf`
- info objects: 1
- title: Portable PDF Fixture
- author: MoonBit Agent
- subject: -
- keywords: -
- creator: pdfskill cram
- producer: portable_cli
- creation date: D:20260530000000Z
- mod date: -
- xmp objects: 1
- xmp preview: `<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF><rdf:Description><dc:title>Portable PDF</dc:title></rdf:Description></rdf:RDF></x:xmpmeta>`
```

```mooncram
$ root="$TESTDIR/../.."; fixture="tests/cram/fixtures/metadata-info.pdf"; moon -C "$root" run --target wasm cmd/pdfskill -- metadata --json --max-bytes 40 "$fixture"
{"author":"MoonBit Agent","creation_date":"D:20260530000000Z","creator":"pdfskill cram","info_objects":1,"keywords":"-","mod_date":"-","path":"tests/cram/fixtures/metadata-info.pdf","producer":"portable_cli","subject":"-","title":"Portable PDF Fixture","xmp_objects":1,"xmp_preview":"<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf"}
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
