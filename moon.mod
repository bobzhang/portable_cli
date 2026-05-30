// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "bobzhang/portable_cli"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/bobzhang/portable_cli"

license = "Apache-2.0"

keywords = [ "cli", "wasm", "wasi", "portable", "miniio" ]

description = "Portable MoonBit CLI examples that compile to WASIp1 and run across WASM runtimes."

import {
  "moonbit-community/miniio@0.2.0",
}
