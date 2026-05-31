///|
struct FileEntry {
  path : String
  is_dir : Bool
  is_file : Bool
}

///|
struct ScanOptions {
  root : String
  include_hidden : Bool
  default_ignore : Bool
  all_files : Bool
  exts : Array[String]
  max_files : Int
  max_bytes : Int
  limit : Int
  output : String?
  as_json : Bool
  fail_on : String
}

///|
struct ScanStats {
  mut files_seen : Int
  mut files_scanned : Int
  mut files_skipped : Int
  mut bytes_scanned : Int
}

///|
struct Finding {
  path : String
  line : Int
  severity : String
  rule : String
  evidence : String
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
    "secretscan",
    about="Scan WASI-visible text files for secret-like values before sharing context.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "json",
        long="json",
        about="write compact JSON instead of Markdown",
      ),
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
        about="comma-separated extensions to include, for example env,json,mbt,md",
      ),
      @argparse.OptionArg(
        "max-files",
        long="max-files",
        about="maximum number of files to scan",
        default_values=["128"],
      ),
      @argparse.OptionArg(
        "max-bytes",
        long="max-bytes",
        about="maximum bytes to inspect per file after reading text",
        default_values=["200000"],
      ),
      @argparse.OptionArg(
        "limit",
        long="limit",
        about="maximum findings to print",
        default_values=["80"],
      ),
      @argparse.OptionArg(
        "fail-on",
        long="fail-on",
        about="exit with status 1 when findings reach low, medium, high, or critical",
        default_values=["none"],
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write scan report to a guest-visible file",
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
    err => die("secretscan: failed to read argv: \{err}", 2)
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
fn normalize_level(level : String) -> String {
  let value = level.to_lower().trim().to_owned()
  if value == "none" ||
    value == "low" ||
    value == "medium" ||
    value == "high" ||
    value == "critical" {
    value
  } else {
    die(
      "secretscan: invalid --fail-on: \{level} (expected none, low, medium, high, or critical)",
      2,
    )
  }
}

///|
fn options_from_matches(matches : @argparse.Matches) -> ScanOptions {
  {
    root: value(matches, "path", "."),
    include_hidden: flag(matches, "hidden"),
    default_ignore: !flag(matches, "no-default-ignore"),
    all_files: flag(matches, "all-files"),
    exts: parse_exts(option(matches, "ext")),
    max_files: int_value(matches, "max-files", 128).clamp(min=1, max=5000),
    max_bytes: int_value(matches, "max-bytes", 200000).clamp(min=0, max=5000000),
    limit: int_value(matches, "limit", 80).clamp(min=0, max=10000),
    output: option(matches, "output"),
    as_json: flag(matches, "json"),
    fail_on: normalize_level(value(matches, "fail-on", "none")),
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
    "cfg", "conf", "css", "env", "go", "h", "html", "ini", "js", "json", "lock",
    "mbt", "md", "py", "rb", "rs", "sh", "toml", "ts", "txt", "xml", "yaml", "yml",
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
fn should_skip_name(name : String, options : ScanOptions) -> Bool {
  if name == "." || name == ".." {
    return true
  }
  if !options.include_hidden && name.has_prefix(".") {
    return true
  }
  options.default_ignore && contains(default_ignored_names(), name)
}

///|
fn should_include_file(path : String, options : ScanOptions) -> Bool {
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
fn collect_children(path : String, options : ScanOptions) -> Array[FileEntry] {
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
fn is_ascii_letter(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  match ch {
    '0'..='9' => true
    _ => false
  }
}

///|
fn is_token_char(ch : Char) -> Bool {
  if is_ascii_letter(ch) || is_ascii_digit(ch) {
    true
  } else {
    match ch {
      '_' | '-' | '.' | '/' | '+' | '=' => true
      _ => false
    }
  }
}

///|
fn token_prefix(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    if is_token_char(ch) {
      out.write_char(ch)
    } else {
      break
    }
  }
  out.to_string()
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
fn tail_chars(text : String, limit : Int) -> String {
  let total = text.char_length()
  if limit <= 0 || total <= limit {
    return text
  }
  let out = StringBuilder()
  let mut index = 0
  for ch in text {
    if index >= total - limit {
      out.write_char(ch)
    }
    index += 1
  }
  out.to_string()
}

///|
fn redact_token(token : String) -> String {
  let length = token.char_length()
  if length <= 8 {
    "[redacted:\{length}]"
  } else {
    "\{take_chars(token, 4)}...\{tail_chars(token, 4)} (\{length} chars)"
  }
}

///|
fn redacted_assignment(key : String, value : String) -> String {
  let trimmed = value.trim().to_owned()
  "\{key.trim().to_owned()}=\{redact_token(trimmed)}"
}

///|
fn add_finding(
  findings : Array[Finding],
  options : ScanOptions,
  path : String,
  line : Int,
  severity : String,
  rule : String,
  evidence : String,
) -> Unit {
  if findings.length() < options.limit {
    findings.push(Finding::{ path, line, severity, rule, evidence })
  }
}

///|
fn secret_keyword(key : String) -> Bool {
  key.contains("secret") ||
  key.contains("token") ||
  key.contains("api_key") ||
  key.contains("apikey") ||
  key.contains("password") ||
  key.contains("passwd") ||
  key.contains("private_key") ||
  key.contains("client_secret") ||
  key.contains("access_key") ||
  key.contains("authorization") ||
  key.contains("credential")
}

///|
fn looks_placeholder(value : String) -> Bool {
  let lower = value.to_lower()
  lower.contains("changeme") ||
  lower.contains("placeholder") ||
  lower.contains("redacted") ||
  lower.contains("your_") ||
  lower.contains("your-") ||
  lower == "todo" ||
  lower == "none" ||
  lower == "null"
}

///|
fn char_classes(value : String) -> Int {
  let mut letters = false
  let mut digits = false
  let mut symbols = false
  for ch in value {
    if is_ascii_letter(ch) {
      letters = true
    } else if is_ascii_digit(ch) {
      digits = true
    } else if is_token_char(ch) {
      symbols = true
    }
  }
  let mut count = 0
  if letters {
    count += 1
  }
  if digits {
    count += 1
  }
  if symbols {
    count += 1
  }
  count
}

///|
fn looks_secret_value(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  trimmed.char_length() >= 12 &&
  !looks_placeholder(trimmed) &&
  char_classes(trimmed) >= 2
}

///|
fn find_assignment_delim(line : String) -> Int {
  let mut index = 0
  while index < line.length() {
    match line.get_char(index) {
      Some('=') | Some(':') => return index
      _ => ()
    }
    index += 1
  }
  -1
}

///|
fn scan_generic_assignment(
  path : String,
  line_no : Int,
  line : String,
  options : ScanOptions,
  findings : Array[Finding],
) -> Unit {
  let split = find_assignment_delim(line)
  if split < 0 || split + 1 >= line.length() {
    return
  }
  let key = line[:split].to_owned()
  let value = line[split + 1:].to_owned()
  if secret_keyword(key.to_lower()) && looks_secret_value(value) {
    add_finding(
      findings,
      options,
      path,
      line_no,
      "medium",
      "secret assignment",
      redacted_assignment(key, value),
    )
  }
}

///|
fn scan_prefixed_token(
  path : String,
  line_no : Int,
  line : String,
  prefix : String,
  min_length : Int,
  severity : String,
  rule : String,
  options : ScanOptions,
  findings : Array[Finding],
) -> Unit {
  let mut first = true
  for part in line.split(prefix) {
    if first {
      first = false
    } else {
      let token = prefix + token_prefix(part.to_owned())
      if token.char_length() >= min_length {
        add_finding(
          findings,
          options,
          path,
          line_no,
          severity,
          rule,
          redact_token(token),
        )
      }
    }
  }
}

///|
fn scan_token_words(
  path : String,
  line_no : Int,
  line : String,
  options : ScanOptions,
  findings : Array[Finding],
) -> Unit {
  for raw in line.split(" ") {
    let token = token_prefix(raw.to_owned())
    if token.char_length() == 20 &&
      (token.has_prefix("AKIA") || token.has_prefix("ASIA")) &&
      char_classes(token) >= 2 {
      add_finding(
        findings,
        options,
        path,
        line_no,
        "critical",
        "aws access key id",
        redact_token(token),
      )
    } else if token.char_length() >= 24 &&
      token.contains(".") &&
      token.split(".").to_array().length() == 3 {
      add_finding(
        findings,
        options,
        path,
        line_no,
        "high",
        "jwt-like token",
        redact_token(token),
      )
    }
  }
}

///|
fn scan_line(
  path : String,
  line_no : Int,
  line : String,
  options : ScanOptions,
  findings : Array[Finding],
) -> Unit {
  if findings.length() >= options.limit {
    return
  }
  let trimmed = line.trim().to_owned()
  if trimmed.contains("-----BEGIN ") && trimmed.contains(" PRIVATE KEY-----") {
    add_finding(
      findings, options, path, line_no, "critical", "private key block", "-----BEGIN ... PRIVATE KEY-----",
    )
  }
  scan_prefixed_token(
    path, line_no, line, "github_pat_", 32, "critical", "github fine-grained token",
    options, findings,
  )
  for prefix in ["ghp_", "gho_", "ghu_", "ghs_", "ghr_"] {
    scan_prefixed_token(
      path, line_no, line, prefix, 24, "critical", "github token", options, findings,
    )
  }
  scan_prefixed_token(
    path, line_no, line, "sk-", 24, "high", "openai-style api key", options, findings,
  )
  for prefix in ["xoxb-", "xoxp-", "xoxa-", "xoxr-"] {
    scan_prefixed_token(
      path, line_no, line, prefix, 24, "high", "slack token", options, findings,
    )
  }
  for prefix in ["AKIA", "ASIA"] {
    scan_prefixed_token(
      path, line_no, line, prefix, 20, "critical", "aws access key id", options,
      findings,
    )
  }
  scan_token_words(path, line_no, line, options, findings)
  scan_generic_assignment(path, line_no, line, options, findings)
}

///|
fn scan_text(
  path : String,
  text : String,
  options : ScanOptions,
  findings : Array[Finding],
) -> Unit {
  let mut line_no = 1
  for line in text.split("\n") {
    scan_line(path, line_no, line.to_owned(), options, findings)
    if findings.length() >= options.limit {
      return
    }
    line_no += 1
  }
}

///|
fn scan_file(
  path : String,
  options : ScanOptions,
  stats : ScanStats,
  findings : Array[Finding],
) -> Unit {
  if stats.files_scanned >= options.max_files ||
    !should_include_file(path, options) {
    return
  }
  stats.files_seen += 1
  let text = @miniio.read_text_file(path) catch {
    _ => {
      stats.files_skipped += 1
      return
    }
  }
  let bytes = text.length()
  stats.files_scanned += 1
  stats.bytes_scanned += bytes
  let content = if bytes > options.max_bytes {
    take_chars(text, options.max_bytes)
  } else {
    text
  }
  scan_text(path, content, options, findings)
}

///|
fn walk(
  path : String,
  options : ScanOptions,
  stats : ScanStats,
  findings : Array[Finding],
) -> Unit {
  if stats.files_scanned >= options.max_files ||
    findings.length() >= options.limit {
    return
  }
  if (@miniio.is_file(path) catch { _ => false }) {
    scan_file(path, options, stats, findings)
    return
  }
  if !(@miniio.is_dir(path) catch { _ => false }) {
    return
  }
  for entry in collect_children(path, options) {
    if stats.files_scanned >= options.max_files ||
      findings.length() >= options.limit {
      return
    }
    if entry.is_dir {
      walk(entry.path, options, stats, findings)
    } else if entry.is_file {
      scan_file(entry.path, options, stats, findings)
    }
  }
}

///|
fn severity_rank(level : String) -> Int {
  match level {
    "critical" => 4
    "high" => 3
    "medium" => 2
    "low" => 1
    _ => 0
  }
}

///|
fn highest_severity(findings : Array[Finding]) -> String {
  let mut highest = "none"
  for finding in findings {
    if severity_rank(finding.severity) > severity_rank(highest) {
      highest = finding.severity
    }
  }
  highest
}

///|
fn should_fail(fail_on : String, findings : Array[Finding]) -> Bool {
  fail_on != "none" &&
  severity_rank(highest_severity(findings)) >= severity_rank(fail_on)
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn finding_json(finding : Finding) -> Json {
  Json::object({
    "evidence": Json::string(finding.evidence),
    "line": int_json(finding.line),
    "path": Json::string(finding.path),
    "rule": Json::string(finding.rule),
    "severity": Json::string(finding.severity),
  })
}

///|
fn json_report(
  options : ScanOptions,
  stats : ScanStats,
  findings : Array[Finding],
) -> String {
  Json::object({
    "bytes_scanned": int_json(stats.bytes_scanned),
    "fail_on": Json::string(options.fail_on),
    "files_scanned": int_json(stats.files_scanned),
    "files_seen": int_json(stats.files_seen),
    "files_skipped": int_json(stats.files_skipped),
    "findings": Json::array(
      [
        for finding in findings => finding_json(finding)
      ],
    ),
    "highest_severity": Json::string(highest_severity(findings)),
    "limit": int_json(options.limit),
    "root": Json::string(options.root),
  }).stringify() +
  "\n"
}

///|
fn markdown_report(
  options : ScanOptions,
  stats : ScanStats,
  findings : Array[Finding],
) -> String {
  let out = StringBuilder()
  out.write_string("# Secret Scan\n\n")
  out.write_string("- root: `\{options.root}`\n")
  out.write_string("- files scanned: \{stats.files_scanned}\n")
  out.write_string("- files skipped: \{stats.files_skipped}\n")
  out.write_string("- bytes scanned: \{stats.bytes_scanned}\n")
  out.write_string("- findings: \{findings.length()}\n")
  out.write_string("- highest severity: \{highest_severity(findings)}\n")
  out.write_string("- fail on: \{options.fail_on}\n")
  out.write_string("\n## Findings\n\n")
  if findings.is_empty() {
    out.write_string("_No secret-like values found._\n")
  } else {
    out.write_string("| severity | rule | file | line | evidence |\n")
    out.write_string("|---|---|---|---:|---|\n")
    for finding in findings {
      out.write_string(
        "| \{finding.severity} | \{finding.rule} | `\{finding.path}` | \{finding.line} | `\{finding.evidence}` |\n",
      )
    }
  }
  out.write_string("\n## Notes\n\n")
  out.write_string(
    "Findings are heuristic and redacted. Review the source file before sharing repository context.\n",
  )
  out.to_string()
}

///|
fn write_output(text : String, output : String?) -> Unit {
  match output {
    Some(path) =>
      @miniio.write_text_file(path, text) catch {
        err => die("secretscan: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(text) catch {
        err => die("secretscan: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let options = options_from_matches(parse())
  let stats = ScanStats::{
    files_seen: 0,
    files_scanned: 0,
    files_skipped: 0,
    bytes_scanned: 0,
  }
  let findings : Array[Finding] = []
  walk(options.root, options, stats, findings)
  let report = if options.as_json {
    json_report(options, stats, findings)
  } else {
    markdown_report(options, stats, findings)
  }
  write_output(report, options.output)
  if should_fail(options.fail_on, findings) {
    @miniio.exit(1)
    panic()
  }
}
