#!/usr/bin/env bash
set -euo pipefail

version="${DOCX2HTML_VERSION:-0.1.40}"
package="bobzhang/docx2html/cmd/docx2html@${version}"

if [ -n "${DOCX2HTML_BIN:-}" ]; then
  exec "$DOCX2HTML_BIN" "$@"
fi

if command -v docx2html >/dev/null 2>&1; then
  exec docx2html "$@"
fi

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/codex-docx2html-skill/${version}"
bin_dir="$cache_root/bin"
bin="$bin_dir/docx2html"
log="$cache_root/install.log"

if [ ! -x "$bin" ]; then
  if ! command -v moon >/dev/null 2>&1; then
    echo "docx2html skill: moon is required to install ${package}" >&2
    exit 127
  fi

  mkdir -p "$bin_dir"
  if ! moon install --bin "$bin_dir" "$package" >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
fi

exec "$bin" "$@"
