///|
struct DiffOptions {
  file : String?
  limit : Int
  output : String?
}

///|
struct DiffFile {
  mut path : String
  mut additions : Int
  mut deletions : Int
  mut hunks : Int
  mut binary : Bool
}

///|
fn[T] die(message : String, code : Int) -> T {
  @miniio.stderr.write_text(message + "\n") catch {
    _ => ()
  }
  @miniio.exit(code)
  panic()
}

///|
fn command() -> @argparse.Command {
  @argparse.Command(
    "diffskill",
    about="Summarize unified diffs into review-focused Markdown.",
    version="0.1.0",
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input diff file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "limit",
        long="limit",
        about="maximum changed files to list",
        default_values=["80"],
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write report to a guest-visible file",
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("diffskill: failed to read argv: \{err}", 2)
  }
  let env = @miniio.get_env_vars() catch { _ => {} }
  command().parse(argv=args[1:], env~) catch {
    err => die(err.to_string(), 2)
  }
}

///|
fn option(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(items) => items.get(0)
    None => None
  }
}

///|
fn value(
  matches : @argparse.Matches,
  name : String,
  fallback : String,
) -> String {
  option(matches, name).unwrap_or(fallback)
}

///|
fn int_value(matches : @argparse.Matches, name : String, fallback : Int) -> Int {
  @string.parse_int(value(matches, name, fallback.to_string())) catch {
    _ => fallback
  }
}

///|
fn options_from_matches(matches : @argparse.Matches) -> DiffOptions {
  {
    file: option(matches, "file"),
    limit: int_value(matches, "limit", 80).clamp(min=0, max=10000),
    output: option(matches, "output"),
  }
}

///|
fn read_input(options : DiffOptions) -> String {
  match options.file {
    Some(path) =>
      @miniio.read_text_file(path) catch {
        err => die("diffskill: failed to read \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdin.read_all().text() catch {
        err => die("diffskill: failed to read stdin: \{err}", 1)
      }
  }
}

///|
fn strip_prefix(text : String, prefix : String) -> String {
  if text.has_prefix(prefix) {
    text[prefix.length():].to_owned()
  } else {
    text
  }
}

///|
fn diff_path(line : String) -> String? {
  if !line.has_prefix("diff --git ") {
    return None
  }
  let parts = line.split(" ").map(part => part.to_owned()).to_array()
  match parts.get(3) {
    Some(path) => Some(strip_prefix(path, "b/"))
    None => None
  }
}

///|
fn plus_path(line : String) -> String? {
  if line.has_prefix("+++ ") {
    let path = line[4:].to_owned()
    if path == "/dev/null" {
      None
    } else {
      Some(strip_prefix(path, "b/"))
    }
  } else {
    None
  }
}

///|
fn new_file(path : String) -> DiffFile {
  DiffFile::{ path, additions: 0, deletions: 0, hunks: 0, binary: false }
}

///|
fn parse_diff(input : String) -> Array[DiffFile] {
  let files : Array[DiffFile] = []
  let mut current : DiffFile? = None
  for raw in input.split("\n") {
    let line = raw.to_owned()
    match diff_path(line) {
      Some(path) => {
        match current {
          Some(file) => files.push(file)
          None => ()
        }
        current = Some(new_file(path))
        continue
      }
      None => ()
    }
    match current {
      Some(file) => {
        match plus_path(line) {
          Some(path) => file.path = path
          None => ()
        }
        if line.has_prefix("@@") {
          file.hunks += 1
        } else if line.has_prefix("Binary files ") {
          file.binary = true
        } else if line.has_prefix("+") && !line.has_prefix("+++") {
          file.additions += 1
        } else if line.has_prefix("-") && !line.has_prefix("---") {
          file.deletions += 1
        }
      }
      None => ()
    }
  }
  match current {
    Some(file) => files.push(file)
    None => ()
  }
  files
}

///|
fn extension(path : String) -> String {
  let mut dot = -1
  let mut slash = -1
  let mut index = 0
  while index < path.length() {
    match path.get_char(index) {
      Some('.') => dot = index
      Some('/') => slash = index
      _ => ()
    }
    index += 1
  }
  if dot > slash && dot + 1 < path.length() {
    path[dot + 1:].to_owned().to_lower()
  } else {
    ""
  }
}

///|
fn is_test_path(path : String) -> Bool {
  path.contains("test") ||
  path.contains("tests/") ||
  path.has_suffix("_test.mbt") ||
  path.has_suffix(".md")
}

///|
fn file_tags(file : DiffFile) -> String {
  let tags : Array[String] = []
  let path = file.path
  if file.binary || extension(path) == "wasm" {
    tags.push("artifact")
  }
  if path == "moon.mod" || path.has_suffix("moon.pkg") {
    tags.push("manifest")
  }
  if path.has_prefix("scripts/") || path.has_prefix(".github/") {
    tags.push("automation")
  }
  if path.has_prefix("skills/") {
    tags.push("skill")
  }
  if is_test_path(path) {
    tags.push("test/docs")
  }
  if tags.is_empty() {
    "code"
  } else {
    tags.join(",")
  }
}

///|
fn total_additions(files : Array[DiffFile]) -> Int {
  files.fold(init=0, (sum, file) => sum + file.additions)
}

///|
fn total_deletions(files : Array[DiffFile]) -> Int {
  files.fold(init=0, (sum, file) => sum + file.deletions)
}

///|
fn total_hunks(files : Array[DiffFile]) -> Int {
  files.fold(init=0, (sum, file) => sum + file.hunks)
}

///|
fn count_with_tag(files : Array[DiffFile], tag : String) -> Int {
  let mut count = 0
  for file in files {
    if file_tags(file).contains(tag) {
      count += 1
    }
  }
  count
}

///|
fn risk_level(files : Array[DiffFile]) -> String {
  if count_with_tag(files, "artifact") > 0 ||
    count_with_tag(files, "manifest") > 0 {
    "high"
  } else if count_with_tag(files, "automation") > 0 ||
    total_additions(files) + total_deletions(files) > 400 {
    "medium"
  } else {
    "low"
  }
}

///|
fn render_hints(files : Array[DiffFile], out : StringBuilder) -> Unit {
  out.write_string("\n## Review Hints\n\n")
  if files.is_empty() {
    out.write_string("- No changed files found in the diff.\n")
    return
  }
  if count_with_tag(files, "artifact") > 0 {
    out.write_string(
      "- Binary or Wasm artifacts changed; verify they were rebuilt from source.\n",
    )
  }
  if count_with_tag(files, "manifest") > 0 {
    out.write_string(
      "- Manifest files changed; check dependency/version intent.\n",
    )
  }
  if count_with_tag(files, "automation") > 0 {
    out.write_string(
      "- Automation scripts changed; run the smoke or CI path.\n",
    )
  }
  if count_with_tag(files, "test/docs") == 0 {
    out.write_string("- No tests or executable docs appear in this diff.\n")
  }
  if risk_level(files) == "low" {
    out.write_string(
      "- Diff looks small; still verify behavior-specific tests.\n",
    )
  }
}

///|
fn render_report(files : Array[DiffFile], options : DiffOptions) -> String {
  files.sort_by((left, right) => left.path.compare(right.path))
  let out = StringBuilder()
  out.write_string("# Diff Skill\n\n")
  out.write_string("- files: \{files.length()}\n")
  out.write_string("- additions: \{total_additions(files)}\n")
  out.write_string("- deletions: \{total_deletions(files)}\n")
  out.write_string("- hunks: \{total_hunks(files)}\n")
  out.write_string("- risk: \{risk_level(files)}\n")
  out.write_string("\n## Changed Files\n\n")
  if files.is_empty() {
    out.write_string("_No changed files found._\n")
  } else {
    out.write_string("| file | + | - | hunks | tags |\n")
    out.write_string("|---|---:|---:|---:|---|\n")
    let limit = options.limit.min(files.length())
    for index in 0..<limit {
      let file = files[index]
      out.write_string(
        "| `\{file.path}` | \{file.additions} | \{file.deletions} | \{file.hunks} | \{file_tags(file)} |\n",
      )
    }
    if limit < files.length() {
      out.write_string(
        "\n_Additional files omitted: \{files.length() - limit}._\n",
      )
    }
  }
  render_hints(files, out)
  out.to_string()
}

///|
fn write_output(text : String, options : DiffOptions) -> Unit {
  let output = if text.has_suffix("\n") { text } else { text + "\n" }
  match options.output {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("diffskill: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("diffskill: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let options = options_from_matches(parse())
  write_output(render_report(parse_diff(read_input(options)), options), options)
}
