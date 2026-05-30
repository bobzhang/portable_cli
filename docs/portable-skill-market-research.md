# Portable Skill Market Research

## Scope

This note looks at "skills" in the broad agent ecosystem: `SKILL.md`-style
instruction packages, MCP tools, and CLI tools that agents can call. The goal is
to identify the most common skill categories and what kind of MoonBit code would
be needed to implement them as portable WASM CLIs.

Popularity signals are directional, not exact. Public directories change
quickly, and GitHub stars often measure repository popularity rather than
runtime usage.

## High-Level Findings

The strongest demand clusters around:

1. Document and file transformation
2. Developer tools
3. Web search, scraping, and browser automation
4. Data and database access
5. Diagrams, design, and presentation assets
6. Research and citation workflows
7. Finance and analytics
8. Security and code review
9. Productivity integrations

MoonBit's best initial fit is not remote SaaS integration. The best fit is
deterministic, sandboxable transformation code:

- parse this file
- convert this file
- format this source
- extract links/text/tables
- validate this manifest
- summarize this repo into a compact artifact
- produce a diagram/document/chart payload

These are exactly the tasks where portable WASM CLIs are attractive.

## Market Signals

### Built-In Skills Focus On Office And Documents

Anthropic's built-in skills include:

- enhanced Excel spreadsheet creation and manipulation
- professional Word document creation
- PowerPoint presentation generation
- PDF creation and processing

That is a strong signal that document/file workflows are a primary skill use
case. These workflows need deterministic code because users expect real files,
not only prose instructions.

Source: <https://support.claude.com/en/articles/12512180-use-skills-in-claude>

### Agent Skill Directories Skew Toward Coding, Design, Docs, And Research

MCP.Directory lists 4,400+ agent skills. Its visible popular skill list includes
many coding and artifact-oriented categories:

- `flutter-development`
- `ui-ux-pro-max`
- `drawio-diagrams-enhanced`
- `pdf-to-markdown`
- `literature-review`
- `svg-precision`
- `fastapi-templates`
- `pptx`
- `slidev`
- `software-architecture`
- `frontend-design`
- `rust-coding-skill`
- `webapp-testing`
- `screenshot-to-code`
- `brand-voice`

This suggests that popular skills often combine domain instructions with
supporting executable tools for parsing, rendering, testing, or generating
artifacts.

Source: <https://mcp.directory/skills>

### MCP Server Categories Show Tool Demand

MCP.Directory's server category counts are a useful proxy for tool demand:

| Category | Count |
| --- | ---: |
| Developer Tools | 925 |
| Productivity | 370 |
| AI & Machine Learning | 289 |
| Analytics & Data | 247 |
| Search & Web | 188 |
| Databases | 142 |
| Finance | 112 |
| Cloud & Infrastructure | 91 |
| Auth & Security | 81 |
| Communication | 79 |
| Browser Automation | 64 |
| File Systems | 54 |
| Design | 33 |

The largest category is developer tools, followed by productivity, data, web,
and database tooling.

Source: <https://mcp.directory/awesome-mcp-servers>

### Official MCP Reference Servers Cover Foundational Capabilities

The MCP reference server repository highlights foundational capabilities:

- `fetch`: web content fetching and conversion
- `filesystem`: secure file operations
- `git`: repository operations
- `memory`: local knowledge graph memory
- `sequentialthinking`: structured problem solving
- `time`: time and timezone conversion

Archived reference examples include GitHub, GitLab, Google Drive, Google Maps,
PostgreSQL, Puppeteer, Redis, Sentry, Slack, and SQLite.

These map to two classes:

- local deterministic tools, which are good MoonBit/WASM candidates
- authenticated network integrations, which are better handled by a host or MCP
  server that can call MoonBit tools internally

Source: <https://github.com/modelcontextprotocol/servers>

### Browser Automation Is Popular But Not Pure-WASM Friendly

Playwright MCP is popular because browser control is useful to agents. The
project describes its server as fast, lightweight, LLM-friendly, and
deterministic through accessibility snapshots. It also notes that coding agents
may benefit from CLI plus skills because concise commands can be more
token-efficient than large MCP schemas and verbose browser trees.

That supports the MoonBit direction: use portable CLIs for compact,
deterministic sub-tasks, and leave full browser ownership to the host.

Source: <https://github.com/microsoft/playwright-mcp>

## What Kind Of Code Popular Skills Need

### 1. Document And File Transformation

Examples:

- PDF to text or Markdown
- DOCX/PPTX/XLSX creation and inspection
- HTML to Markdown
- Markdown to slides
- SVG validation and cleanup
- CSV/JSON/YAML/TOML conversion

Code needed:

- parsers and serializers
- ZIP container support for Office formats
- XML reader/writer
- table model and formula utilities
- Markdown and HTML ASTs
- image metadata inspection
- text extraction and layout heuristics
- path-safe file IO
- clear CLI contracts and output modes

MoonBit fit: excellent, especially for HTML, Markdown, JSON, TOML, CSV, XML,
SVG, and Office package manipulation once ZIP/XML libraries are available.

### 2. Developer Tools

Examples:

- repo packing for AI context
- code search and filtering
- dependency manifest inspection
- changelog generation
- diff statistics
- codeowner validation
- lockfile analysis
- AST-based lint helpers

Code needed:

- directory traversal
- glob matching
- ignore-file parsing
- Git diff and patch parsing
- lockfile parsers
- package manifest parsers
- language-aware tokenizers
- compact Markdown output
- deterministic sorting and hashing

MoonBit fit: excellent. These are mostly local, deterministic, and small.

### 3. Web Search, Scraping, And HTML Processing

Examples:

- fetch a web page and extract clean text
- extract links, headings, tables, metadata
- sanitize HTML
- convert HTML to Markdown
- produce compact page context for an agent

Code needed:

- URL parsing and normalization
- HTML parsing
- CSS selector matching
- sanitizer
- readability extraction
- HTML-to-Markdown renderer
- table extraction
- optional host-provided HTTP fetch

MoonBit fit: strong for the parsing and transformation parts. Network fetch
should initially be host-provided, with the MoonBit CLI taking stdin or a file.

This repository already proves the first step with `cmd/htmlfmt`.

### 4. Browser Automation

Examples:

- click and type in a browser
- inspect accessibility tree
- capture screenshots
- replay traces
- generate selectors
- analyze console/network logs

Code needed:

- browser protocol bindings
- accessibility tree parser
- DOM snapshot parser
- locator ranking
- trace and HAR parsers
- screenshot/image tools
- state/session handling

MoonBit fit: mixed. Pure browser control is not a good first target for a
WASIp1 CLI because it needs a browser process and host integration. MoonBit can
still provide helper CLIs for DOM snapshot compaction, locator generation, HAR
analysis, and trace summarization.

### 5. Data And Database Tools

Examples:

- CSV profiling
- SQL formatting
- schema diffing
- SQLite inspection
- Postgres query advice
- vector-store export/import

Code needed:

- CSV/TSV parser
- SQL lexer/formatter
- statistics and type inference
- schema model
- safe query rendering
- SQLite file reader or host-mediated database access
- JSONL and Parquet support

MoonBit fit: strong for offline data files and schema/text transforms. Live
database connections are better mediated by a host runtime.

### 6. Diagrams, Design, And Presentations

Examples:

- Mermaid generation and validation
- Draw.io XML editing
- SVG optimization
- PPTX generation
- design token validation
- screenshot-to-code post-processing

Code needed:

- XML/SVG parsers
- graph model
- layout helpers
- color and unit parsers
- ZIP/XML for PPTX
- CSS parser subset
- asset manifest generation

MoonBit fit: strong for validators, transformers, and deterministic generators.
Full visual rendering is harder, but many design skills only need structured
asset generation.

### 7. Research And Citation Workflows

Examples:

- literature review
- arXiv or PubMed lookup
- DOI normalization
- BibTeX cleanup
- citation formatting
- paper metadata extraction

Code needed:

- BibTeX/RIS/CSL JSON parsers
- DOI/URL normalization
- Markdown report assembly
- metadata deduplication
- host-mediated API fetch
- PDF text extraction for local files

MoonBit fit: good for citation and metadata transforms. External search should
initially be host-provided.

### 8. Finance And Analytics

Examples:

- stock analysis
- financial statement parsing
- market sizing
- time-series indicators
- chart data generation

Code needed:

- CSV/XLSX ingest
- date and timezone handling
- decimal arithmetic
- time-series window functions
- statistics
- chart JSON generation
- source attribution handling

MoonBit fit: good for deterministic analytics over supplied data. Live market
data should be host-provided because credentials and rate limits vary.

### 9. Security And Review

Examples:

- secret scanning
- dependency audits
- SBOM validation
- prompt injection linting
- code review checklists
- license scanning

Code needed:

- manifest parsers
- lockfile parsers
- regex/pattern engine
- entropy detection
- SPDX/SBOM parsing
- diff parsing
- policy rule engine

MoonBit fit: strong. These tools benefit from deterministic, sandboxed
execution and clear machine-readable outputs.

### 10. Productivity Integrations

Examples:

- Notion
- Slack
- Jira
- Gmail
- Google Drive
- Confluence
- Trello
- calendars

Code needed:

- API clients
- OAuth/token handling
- pagination and retries
- object mappers
- Markdown conversion
- conflict handling

MoonBit fit: weaker as standalone WASM CLIs because credentials, network, and
OAuth flows are host-specific. Better approach: MCP or host integration handles
auth and fetches JSON; MoonBit CLIs transform, validate, diff, or summarize the
data.

## Recommended MoonBit Portable Skill Roadmap

### Tier 1: High Fit, Low External Dependency

These are the best next examples after `htmlfmt`.

| Skill CLI | Purpose | Key Code |
| --- | --- | --- |
| `htmltext` | HTML to clean text | HTML parser, block separators, whitespace policy |
| `html2md` | HTML to Markdown | HTML parser, Markdown renderer |
| `htmlselect` | CSS selector extraction | HTML parser, selector engine, output modes |
| `sanitize-html` | safe HTML cleanup | sanitizer policy, URL handling |
| `repopack` | compact repo into Markdown | tree walk, ignore rules, file filters |
| `diffstat` | summarize patches | unified diff parser |
| `csvstat` | profile CSV files | CSV parser, type inference, stats |
| `jsonlint` | validate/format/extract JSON | JSON parser, path selector |
| `tomlfmt` | format TOML | TOML parser/serializer |
| `svgcheck` | inspect/clean SVG | XML parser, SVG policy |

### Tier 2: Needs Foundational Libraries

These would be compelling but require more infrastructure.

| Skill CLI | Needed Foundation |
| --- | --- |
| `docx-inspect` | ZIP, XML, WordprocessingML helpers |
| `pptx-inspect` | ZIP, XML, DrawingML helpers |
| `xlsx-inspect` | ZIP, XML, shared strings, workbook model |
| `pdftext` | PDF parser/text extractor |
| `bibclean` | BibTeX/RIS/CSL parsers |
| `sqlfmt` | SQL lexer/parser |
| `secret-scan` | regex/pattern/entropy library |

### Tier 3: Host-Assisted Skills

These should probably be split between host integration and MoonBit transforms.

| Skill Area | Host Does | MoonBit Does |
| --- | --- | --- |
| Browser automation | launch browser, navigate, capture snapshots | parse DOM/HAR/trace, rank locators, compact output |
| Web research | fetch pages, manage network and credentials | extract text/tables/links, deduplicate, render Markdown |
| GitHub/Jira/Slack | auth and API pagination | transform JSON, summarize diffs/issues/messages |
| Databases | connection, credentials, query execution | format SQL, inspect schemas, summarize results |

## Code Architecture For Portable Skills

Each skill should have:

- `cmd/<name>/moon.pkg` with `supported_targets = "wasm"`
- `@argparse` command definition
- `miniio` stdin/stdout/stderr/file IO
- `--file` and stdin support
- `--output` for guest-visible file writes
- `--format json|text|markdown` when useful
- deterministic sorting and stable output
- Cram examples in `tests/cram`
- direct Wasmtime smoke coverage

Recommended result shape:

```text
stdout: primary result
stderr: diagnostics only
exit 0: success
exit 1: valid invocation but failed operation
exit 2: CLI usage error
```

For machine consumption, prefer JSON output behind a flag:

```sh
moon run --target wasm cmd/htmlselect -- --format json --selector 'a[href]'
```

## Libraries MoonBit Should Prioritize

To make MoonBit strong for portable skills, prioritize reusable libraries for:

- ZIP/deflate
- XML pull parser and writer
- CSV/TSV streaming parser
- Markdown AST and renderer
- HTML to Markdown
- URL parser
- glob and ignore-file matching
- unified diff parser
- JSON Pointer / simple query paths
- YAML parser
- SQL tokenizer/formatter
- BibTeX/RIS/CSL JSON
- SPDX/SBOM
- SHA-256 and checksums

These foundations would unlock many high-demand skills without needing network
or heavyweight host dependencies.

## Conclusion

The market pattern strongly supports portable MoonBit skills, but the winning
shape is not "MoonBit replaces MCP." The better model is:

- MoonBit builds small deterministic WASM CLIs.
- Skills use those CLIs for compact, reliable transformations.
- Cram files document and test the behavior.
- Hosts or MCP servers handle credentials, browser ownership, and network APIs.
- Mooncakes eventually distributes source plus prebuilt WASM artifacts.

The most promising first category is file/document/developer tooling. It has
high demand, clear boundaries, strong sandboxing benefits, and relatively small
runtime artifacts.

`cmd/htmlfmt` is a good proof point: it uses a real published parser package,
compiles to a sub-1MB release WASM module, runs under Wasmtime, and is tested
with executable Cram documentation.
