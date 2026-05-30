#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  repopack-wasm.sh [--workdir DIR] [--no-build] -- [REPOPACK_ARGS...]

Examples:
  repopack-wasm.sh --workdir . -- --max-files 40 --max-chars 4000 .
  repopack-wasm.sh --workdir ../project -- --ext mbt,md --output repo-pack.md .

The wrapper builds and runs cmd/repopack as release WASM under Wasmtime. The
workdir is preopened as guest "."; pass guest-relative paths after "--".
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
workdir=$(pwd)
build=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workdir)
      if [ "$#" -lt 2 ]; then
        echo "repopack-wasm: --workdir requires a directory" >&2
        exit 2
      fi
      workdir=$2
      shift 2
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

if ! command -v wasmtime >/dev/null 2>&1; then
  echo "repopack-wasm: wasmtime is required" >&2
  exit 127
fi

workdir=$(CDPATH= cd -- "$workdir" && pwd)
wasm="$repo_root/_build/wasm/release/build/cmd/repopack/repopack.wasm"
runtime="$repo_root/wasm/moonbit-sys-unstable.wat"

if [ "$build" = 1 ]; then
  moon -C "$repo_root" build --target wasm --release cmd/repopack >/dev/null
fi

if [ ! -f "$wasm" ]; then
  echo "repopack-wasm: missing WASM artifact: $wasm" >&2
  exit 1
fi

if [ ! -f "$runtime" ]; then
  echo "repopack-wasm: missing runtime preload: $runtime" >&2
  exit 1
fi

exec wasmtime run \
  --dir "$workdir"::. \
  --preload __moonbit_sys_unstable="$runtime" \
  "$wasm" "$@"
