#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  repopack-moonrun.sh [--workdir DIR] [--release|--debug] [--no-build] -- [REPOPACK_ARGS...]

Examples:
  repopack-moonrun.sh --workdir . -- --max-files 40 --max-chars 4000 .
  repopack-moonrun.sh --workdir ../project -- --ext mbt,md --output repo-pack.md .

The wrapper builds cmd/repopack with moon, then runs the WASM artifact with
moonrun from the selected workdir. Pass guest-relative paths after "--".
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
workdir=$(pwd)
build_mode=release
build=1

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
    --release)
      build_mode=release
      shift
      ;;
    --debug)
      build_mode=debug
      shift
      ;;
    --no-build)
      build=0
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

if ! command -v moon >/dev/null 2>&1; then
  echo "repopack-moonrun: moon is required" >&2
  exit 127
fi

if ! command -v moonrun >/dev/null 2>&1; then
  echo "repopack-moonrun: moonrun is required" >&2
  exit 127
fi

workdir=$(CDPATH= cd -- "$workdir" && pwd)
wasm="$repo_root/_build/wasm/$build_mode/build/cmd/repopack/repopack.wasm"

if [ "$build" = 1 ]; then
  if [ "$build_mode" = release ]; then
    moon -q -C "$repo_root" build --target wasm --release cmd/repopack
  else
    moon -q -C "$repo_root" build --target wasm cmd/repopack
  fi
fi

if [ ! -f "$wasm" ]; then
  echo "repopack-moonrun: missing WASM artifact: $wasm" >&2
  exit 1
fi

cd "$workdir"
exec moonrun "$wasm" "$@"
