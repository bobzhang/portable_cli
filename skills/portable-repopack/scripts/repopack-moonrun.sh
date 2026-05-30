#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  repopack-moonrun.sh [--workdir DIR] -- [REPOPACK_ARGS...]

Examples:
  repopack-moonrun.sh --workdir . -- --max-files 40 --max-chars 4000 .
  repopack-moonrun.sh --workdir ../project -- --ext mbt,md --output repo-pack.md .

The wrapper runs the bundled repopack.wasm artifact with moonrun from the
selected workdir. Pass guest-relative paths after "--".
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workdir=$(pwd)

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workdir)
      if [ "$#" -lt 2 ]; then
        echo "repopack-moonrun: --workdir requires a directory" >&2
        exit 2
      fi
      workdir=$2
      shift 2
      ;;
    --release|--debug|--no-build)
      # Accepted for compatibility with earlier wrapper revisions.
      shift
      ;;
    --help-wrapper)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if ! command -v moonrun >/dev/null 2>&1; then
  echo "repopack-moonrun: moonrun is required" >&2
  exit 127
fi

workdir=$(CDPATH= cd -- "$workdir" && pwd)
wasm="$script_dir/../assets/repopack.wasm"

if [ ! -f "$wasm" ]; then
  echo "repopack-moonrun: missing bundled WASM artifact: $wasm" >&2
  exit 1
fi

cd "$workdir"
exec moonrun "$wasm" "$@"
