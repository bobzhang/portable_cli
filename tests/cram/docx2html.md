# DOCX2HTML Skill

The `docx2html` skill wraps the native MoonBit `bobzhang/docx2html` CLI. The
wrapper installs and caches the binary on first use, then delegates all
arguments unchanged.

## Help

```mooncram
$ root="$TESTDIR/../.."; "$root/skills/docx2html/scripts/docx2html.sh" --help | sed -n '1,4p'
Usage: docx2html [options] <input> [output]

Convert DOCX documents to HTML or Markdown.

```
