# Proposal: Portable WASM CLI Artifacts for MoonBit

## Summary

MoonBit should make portable command-line tools a first-class publishing and
running workflow.

For executable packages, especially packages using `miniio` and
`@argparse`, `moon publish` should be able to publish compiled WASIp1 `.wasm`
artifacts together with source packages. `moon run` should then be able to run
those published artifacts directly, without requiring users to know the build
layout, runtime flags, or Wasmtime-specific details.

This turns a MoonBit CLI package into a portable skill: a small, documented,
runtime-neutral tool that can be called by humans, scripts, agents, and any
WASI-compatible host.

## Motivation

MoonBit already has the ingredients for portable CLIs:

- `supported_targets = "wasm"` lets a package declare WASM intent.
- `options(is_main: true)` marks executable packages.
- `moon run --target wasm` can run a main package locally.
- `miniio` provides portable WASIp1 IO.
- `@argparse` provides stable CLI contracts for arguments, help, version, and
  errors.
- Moon Cram can store examples as executable documentation.
- Wasmtime or another WASI runtime can independently validate that the artifact
  is not only Moon-runnable, but runtime-portable.

The missing piece is distribution ergonomics. Today, users normally receive the
source package and rebuild. For portable skills, the compiled `.wasm` should be
publishable and runnable out of the box.

## Rust Ecosystem Precedent

Rust has the same demand, and its ecosystem has several overlapping approaches.

### WASIp1 CLI Modules

Rust supports a `wasm32-wasip1` target. This target produces core WebAssembly
modules that import `wasi_snapshot_preview1` functions for OS-style operations
such as printing and file access.

Typical Rust flow:

```sh
rustup target add wasm32-wasip1
cargo build --target wasm32-wasip1 --release
wasmtime run target/wasm32-wasip1/release/my-cli.wasm --help
```

This is close to the current MoonBit flow:

```sh
moon build --target wasm cmd/cow
wasmtime run _build/wasm/debug/build/cmd/cow/cow.wasm --help
```

The model works, but users still need to know the target, output path, and
runtime invocation.

### WASIp2 Components

Rust also has a `wasm32-wasip2` target. Unlike WASIp1, this target emits a
WebAssembly component rather than only a core module. WASIp2 components use the
WebAssembly Component Model and are intended to make host capabilities and
cross-language interfaces more explicit.

Typical Rust flow:

```sh
cargo build --target wasm32-wasip2 --release
wasmtime run target/wasm32-wasip2/release/my-cli.wasm --help
```

This points to a longer-term direction for MoonBit: WASIp1 is enough for simple
portable CLIs, while WASIp2/components may become the better format for richer
portable skills with typed interfaces.

### cargo-component

The Bytecode Alliance `cargo component` tool explores what first-class
WebAssembly Component Model support for Rust could look like.

It supports workflows such as:

```sh
cargo component new my-component
cargo component build
cargo component publish
```

Its design goal is similar to what MoonBit can learn from: component
dependencies can be declared in `Cargo.toml`, bindings are generated, and the
build output is a reusable WebAssembly component.

For MoonBit, the equivalent should feel native to `moon` rather than requiring a
separate tool for the common CLI case.

### wkg And Component Registries

The `wasm-pkg-tools` project provides `wkg`, a CLI for fetching and publishing
WebAssembly components and WIT packages. It can publish components by package
name and can also push or pull artifacts through OCI registries.

That registry model is useful, but it is more general than simple CLI
distribution. A Mooncakes-native design can be simpler for MoonBit users:

- Mooncakes remains the source package registry.
- Mooncakes can attach runnable WASM artifacts for executable packages.
- `moon run` can hide the artifact lookup and runtime invocation.
- Component registries can still be supported later for WASIp2 and WIT-based
  interoperability.

### Gap In Rust

Rust has strong WASM and WASI building blocks, but the user-facing story is
fragmented:

- crates.io distributes source crates, not usually ready-to-run WASM CLI
  artifacts.
- `wasm32-wasip1` is good for portable CLI modules.
- `wasm32-wasip2` and `cargo component` are promising for typed components.
- `wkg` handles component and WIT distribution, often through OCI registries.
- Runtimes such as Wasmtime execute the final artifact.

MoonBit can provide a more integrated path:

```sh
moon publish --include-wasm
moon run bobzhang/portable_cli/cmd/cow -- --help
```

That would combine the source package, compiled artifact, CLI docs, Cram tests,
and runtime invocation in one toolchain.

## Goals

- Publish verified `.wasm` artifacts for executable MoonBit packages.
- Let `moon run` run published WASM CLIs directly.
- Keep source packages as the canonical package format.
- Attach enough metadata for safe, predictable execution.
- Use Cram tests as the human-readable and machine-checked CLI contract.
- Support runtime-neutral WASIp1 execution, not only one host runtime.

## Non-Goals

- Replacing source packages with binary-only packages.
- Hiding WASI capabilities from users.
- Requiring Wasmtime specifically at runtime.
- Supporting every MoonBit backend in the first version.
- Inventing a plugin system before the CLI artifact model is solid.

## Publishing Model

When `moon publish` sees executable packages that support `wasm`, it can build
and attach WASM artifacts.

Example package metadata:

```moonbit
supported_targets = "wasm"

options(
  is_main: true,
)
```

Possible publish command:

```sh
moon publish --include-wasm
```

The default could later become automatic when all executable WASM packages pass
the required checks.

The published package would include:

- source package archive
- compiled `.wasm` artifact for each selected executable package
- artifact manifest
- checksum for each artifact
- optional Cram transcript bundle
- optional generated command index

## Artifact Manifest

Each published executable artifact should have explicit metadata.

Example manifest:

```json
{
  "module": "bobzhang/portable_cli",
  "version": "0.1.0",
  "package": "cmd/cow",
  "artifact": "cmd/cow/cow.wasm",
  "target": "wasm",
  "abi": "wasi_snapshot_preview1",
  "entry": "command",
  "checksum": {
    "algorithm": "sha256",
    "value": "..."
  },
  "cli": {
    "name": "cow",
    "argv": true,
    "stdin": "optional-text",
    "stdout": "text",
    "stderr": "text",
    "env": [
      {
        "name": "COW_WIDTH",
        "required": false,
        "description": "Default speech bubble width."
      }
    ],
    "preopens": []
  },
  "tests": {
    "cram": [
      "tests/cram/wasm_cli.md"
    ]
  }
}
```

For filesystem tools, preopens should be explicit:

```json
{
  "cli": {
    "name": "tree",
    "preopens": [
      {
        "guest": ".",
        "mode": "read"
      }
    ]
  }
}
```

## Running Model

Local source execution should keep working:

```sh
moon run --target wasm cmd/cow -- --help
```

Published artifact execution should be similarly direct:

```sh
moon run bobzhang/portable_cli/cmd/cow -- --help
```

or, if an explicit artifact mode is preferred:

```sh
moon run --wasm bobzhang/portable_cli/cmd/cow -- --help
```

`moon run` should handle:

- downloading or locating the package artifact
- verifying checksums
- selecting a compatible WASI runtime
- applying declared environment and preopen rules
- forwarding argv after `--`
- forwarding stdin, stdout, and stderr
- reporting runtime errors in a Moon-friendly way

Users should not need to know paths like:

```text
_build/wasm/debug/build/cmd/cow/cow.wasm
```

They also should not need to manually provide runtime-specific preload shims for
normal published artifacts.

## Cram As Contract Documentation

Cram tests should be treated as executable CLI documentation.

For example:

```markdown
```mooncram
$ moon run --target wasm cmd/cow -- --width 18 portable wasm cli
 ___________________
< portable wasm cli >
 -------------------
```
```

These examples serve three roles:

- documentation for users
- regression tests for maintainers
- behavioral contracts for portable skill hosts

For published artifacts, Mooncakes could display linked Cram examples and
optionally show whether they passed during publish.

## Verification Pipeline

Before publishing a WASM artifact, `moon publish` should verify:

1. `moon check --target wasm`
2. `moon test --target wasm`
3. `moon cram test tests/cram`, if Cram tests exist
4. direct WASI runtime execution for each artifact, when a runtime is available
5. checksum generation after final artifact build

For this repository, the proof looks like:

```sh
moon build --target wasm cmd/cow cmd/jqlet cmd/tree cmd/pulse
wasmtime run --preload __moonbit_sys_unstable=wasm/moonbit-sys-unstable.wat \
  _build/wasm/debug/build/cmd/cow/cow.wasm --help
```

Longer term, the published artifact should not require a user-visible preload
shim. The toolchain should either emit a standalone WASIp1-compatible module or
store the required runtime adapter as part of the artifact metadata.

## Portable Skill Shape

A portable skill can be modeled as:

- one or more WASM CLI artifacts
- a CLI contract from `@argparse`
- declared IO capabilities from the artifact manifest
- Cram examples as checked documentation
- optional host integration metadata

Example skill use:

```sh
moon run bobzhang/portable_cli/cmd/jqlet -- --get 'items[0].name' --raw
```

The same artifact should be callable from:

- a developer shell
- an agent runtime
- a CI job
- a server process embedding a WASI runtime
- another language host that can run WASIp1

## Security And Capability Model

Published WASM CLIs should run with least privilege by default.

Recommended defaults:

- no filesystem access unless declared and granted
- no ambient network access
- explicit env allowlist
- explicit preopened directories
- deterministic stdout/stderr behavior
- checksum verification before execution

This is one reason WASM CLIs are a good fit for portable skills: the runtime can
grant only the capabilities required by the manifest.

## Versioning

The source package and WASM artifact should share the same semantic version.

For example:

```text
bobzhang/portable_cli@0.1.0
bobzhang/portable_cli/cmd/cow@0.1.0
```

If the CLI behavior changes, the package version should change. Cram diffs make
such changes visible in review.

## Open Questions

- Should WASM artifacts be published by default for all `is_main` packages that
  support `wasm`, or only with an explicit flag?
- Should artifact metadata live in `moon.pkg`, generated publish metadata, or a
  separate manifest file?
- How should `moon run` choose between locally building source and downloading a
  published artifact?
- Should Mooncakes support multiple runtime ABIs, such as WASIp1 and WASIp2?
- How should large artifacts and multiple optimization profiles be represented?
- Should Cram tests run against `moon run --target wasm`, direct runtime
  execution, or both?

## Recommendation

Start with an opt-in publish flow:

```sh
moon publish --include-wasm
```

Require:

- `is_main: true`
- `supported_targets = "wasm"`
- successful `moon check --target wasm`
- generated artifact manifest
- checksum per `.wasm`

Then add direct artifact execution:

```sh
moon run bobzhang/portable_cli/cmd/cow -- --help
```

Once the flow is stable, Mooncakes can expose the artifacts, checksums, Cram
docs, and install/run commands as part of the package page.

## References

- Rust `wasm32-wasip1` target:
  <https://doc.rust-lang.org/stable/rustc/platform-support/wasm32-wasip1.html>
- Rust `wasm32-wasip2` target:
  <https://doc.rust-lang.org/stable/rustc/platform-support/wasm32-wasip2.html>
- Bytecode Alliance runnable Rust components:
  <https://component-model.bytecodealliance.org/language-support/creating-runnable-components/rust.html>
- `cargo component`:
  <https://github.com/bytecodealliance/cargo-component>
- WebAssembly component distribution and `wkg`:
  <https://component-model.bytecodealliance.org/composing-and-distributing/distributing.html>
- `wasm-pkg-tools`:
  <https://github.com/bytecodealliance/wasm-pkg-tools>
