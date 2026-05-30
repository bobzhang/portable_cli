///|
struct FileEntry {
  path : String
  is_dir : Bool
  is_file : Bool
}

///|
struct PackOptions {
  root : String
  include_hidden : Bool
  default_ignore : Bool
  all_files : Bool
  exts : Array[String]
  max_files : Int
  max_chars : Int
  output : String?
}

///|
struct PackedFile {
  path : String
  chars : Int
  truncated : Bool
  content : String
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
    "repopack",
    about="Pack WASI-visible text files into deterministic Markdown context.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "hidden",
        long="hidden",
        about="include hidden entries; default is to skip names starting with .",
      ),
      @argparse.FlagArg(
        "no-default-ignore",
        long="no-default-ignore",
        about="disable built-in ignores such as .git, _build, and node_modules",
      ),
      @argparse.FlagArg(
        "all-files",
        long="all-files",
        about="try every readable text file instead of filtering by extension",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "ext",
        short='e',
        long="ext",
        about="comma-separated extensions to include, for example mbt,md,json",
      ),
      @argparse.OptionArg(
        "max-files",
        long="max-files",
        about="maximum number of files to include",
        default_values=["64"],
      ),
      @argparse.OptionArg(
        "max-chars",
        long="max-chars",
        about="maximum characters to include per file",
        default_values=["8000"],
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write Markdown bundle to a guest-visible file",
      ),
    ],
    positionals=[
      @argparse.PositionArg("path", about="root file or directory", default_values=[
        ".",
      ]),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("repopack: failed to read argv: \{err}", 2)
  }
  let env = @miniio.get_env_vars() catch { _ => {} }
  command().parse(argv=args[1:], env~) catch {
    err => die(err.to_string(), 2)
  }
}

///|
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get(name).unwrap_or(false)
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
fn path_join(parent : String, child : String) -> String {
  if parent == "" || parent == "." {
    child
  } else if parent.has_suffix("/") {
    parent + child
  } else {
    parent + "/" + child
  }
}

///|
fn extension(name : String) -> String {
  let mut dot = -1
  let mut slash = -1
  let mut i = 0
  while i < name.length() {
    match name.get_char(i) {
      Some('.') => dot = i
      Some('/') => slash = i
      _ => ()
    }
    i += 1
  }
  if dot > slash && dot + 1 < name.length() {
    name[dot + 1:].to_owned().to_lower()
  } else {
    ""
  }
}

///|
fn contains(items : Array[String], item : String) -> Bool {
  for candidate in items {
    if candidate == item {
      return true
    }
  }
  false
}

///|
fn normalize_ext(raw : StringView) -> String {
  let value = raw.trim().to_owned().to_lower()
  if value.has_prefix(".") {
    value[1:].to_owned()
  } else {
    value
  }
}

///|
fn parse_exts(text : String?) -> Array[String] {
  match text {
    Some(items) => {
      let exts : Array[String] = []
      for item in items.split(",") {
        let normalized = normalize_ext(item)
        if !normalized.is_empty() {
          exts.push(normalized)
        }
      }
      exts
    }
    None => []
  }
}

///|
fn default_exts() -> Array[String] {
  [
    "c", "css", "go", "h", "html", "js", "json", "mbt", "mbti", "md", "py", "rs",
    "sh", "svg", "toml", "ts", "txt", "xml", "yaml", "yml",
  ]
}

///|
fn default_ignored_names() -> Array[String] {
  [
    ".DS_Store", ".git", ".moonagent", ".mooncakes", ".repos", ".tmp", "_build",
    "node_modules", "target",
  ]
}

///|
fn should_skip_name(name : String, options : PackOptions) -> Bool {
  if name == "." || name == ".." {
    return true
  }
  if !options.include_hidden && name.has_prefix(".") {
    return true
  }
  options.default_ignore && contains(default_ignored_names(), name)
}

///|
fn should_include_file(path : String, options : PackOptions) -> Bool {
  if options.all_files {
    return true
  }
  let allowed = if options.exts.is_empty() {
    default_exts()
  } else {
    options.exts
  }
  contains(allowed, extension(path))
}

///|
fn collect_children(path : String, options : PackOptions) -> Array[FileEntry] {
  let names = @miniio.readdir(path, include_hidden=true, sort=true) catch {
    _ => return []
  }
  let entries : Array[FileEntry] = []
  for name in names {
    if should_skip_name(name, options) {
      continue
    }
    let child_path = path_join(path, name)
    let is_dir = @miniio.is_dir(child_path) catch { _ => false }
    let is_file = @miniio.is_file(child_path) catch { _ => false }
    entries.push(FileEntry::{ path: child_path, is_dir, is_file })
  }
  entries.sort_by((left, right) => {
    left.path.to_lower().compare(right.path.to_lower())
  })
  entries
}

///|
fn take_chars(text : String, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  let out = StringBuilder()
  let mut count = 0
  for ch in text {
    if count >= limit {
      break
    }
    out.write_char(ch)
    count += 1
  }
  out.to_string()
}

///|
fn pack_file(
  path : String,
  options : PackOptions,
  files : Array[PackedFile],
) -> Unit {
  if files.length() >= options.max_files || !should_include_file(path, options) {
    return
  }
  let text = @miniio.read_text_file(path) catch { _ => return }
  let chars = text.char_length()
  let truncated = chars > options.max_chars
  let content = if truncated {
    take_chars(text, options.max_chars)
  } else {
    text
  }
  files.push(PackedFile::{ path, chars, truncated, content })
}

///|
fn walk(
  path : String,
  options : PackOptions,
  files : Array[PackedFile],
) -> Unit {
  if files.length() >= options.max_files {
    return
  }
  if (@miniio.is_file(path) catch { _ => false }) {
    pack_file(path, options, files)
    return
  }
  if !(@miniio.is_dir(path) catch { _ => false }) {
    return
  }
  for entry in collect_children(path, options) {
    if files.length() >= options.max_files {
      return
    }
    if entry.is_dir {
      walk(entry.path, options, files)
    } else if entry.is_file {
      pack_file(entry.path, options, files)
    }
  }
}

///|
fn fence_lang(path : String) -> String {
  match extension(path) {
    "c" => "c"
    "css" => "css"
    "go" => "go"
    "h" => "c"
    "html" => "html"
    "js" => "javascript"
    "json" => "json"
    "mbt" => "moonbit"
    "mbti" => "moonbit"
    "md" => "markdown"
    "py" => "python"
    "rs" => "rust"
    "sh" => "sh"
    "svg" => "xml"
    "toml" => "toml"
    "ts" => "typescript"
    "xml" => "xml"
    "yaml" => "yaml"
    "yml" => "yaml"
    _ => "text"
  }
}

///|
fn render_markdown(files : Array[PackedFile], options : PackOptions) -> String {
  files.sort_by((left, right) => {
    left.path.to_lower().compare(right.path.to_lower())
  })
  let out = StringBuilder()
  out.write_string("# Repo Pack\n\n")
  out.write_string("- root: `\{options.root}`\n")
  out.write_string("- files: \{files.length()}\n")
  out.write_string("- max chars per file: \{options.max_chars}\n")
  if !options.exts.is_empty() {
    out.write_string("- extensions: `\{options.exts.join(",")}`\n")
  }
  out.write_string("\n## Included Files\n\n")
  if files.is_empty() {
    out.write_string("_No files matched._\n")
  } else {
    for file in files {
      let suffix = if file.truncated { " (truncated)" } else { "" }
      out.write_string("- `\{file.path}` - \{file.chars} chars\{suffix}\n")
    }
  }
  out.write_string("\n## File Contents\n")
  for file in files {
    out.write_string("\n### `\{file.path}`\n\n")
    out.write_string("~~~~\{fence_lang(file.path)}\n")
    out.write_string(file.content)
    if !file.content.has_suffix("\n") {
      out.write_string("\n")
    }
    if file.truncated {
      out.write_string("\n[truncated]\n")
    }
    out.write_string("~~~~\n")
  }
  out.to_string()
}

///|
fn options_from_matches(matches : @argparse.Matches) -> PackOptions {
  {
    root: value(matches, "path", "."),
    include_hidden: flag(matches, "hidden"),
    default_ignore: !flag(matches, "no-default-ignore"),
    all_files: flag(matches, "all-files"),
    exts: parse_exts(option(matches, "ext")),
    max_files: int_value(matches, "max-files", 64).clamp(min=1, max=1000),
    max_chars: int_value(matches, "max-chars", 8000).clamp(min=0, max=200000),
    output: option(matches, "output"),
  }
}

///|
fn write_output(text : String, output : String?) -> Unit {
  match output {
    Some(path) =>
      @miniio.write_text_file(path, text) catch {
        err => die("repopack: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(text) catch {
        err => die("repopack: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let matches = parse()
  let options = options_from_matches(matches)
  let files : Array[PackedFile] = []
  walk(options.root, options, files)
  write_output(render_markdown(files, options), options.output)
}
