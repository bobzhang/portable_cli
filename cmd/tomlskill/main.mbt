///|
struct TomlTable {
  line : Int
  name : String
  array : Bool
}

///|
struct TomlKey {
  line : Int
  table : String
  table_line : Int
  name : String
  path : String
  kind : String
  value : String
}

///|
struct TomlIssue {
  severity : String
  line : Int
  message : String
}

///|
struct TomlReport {
  lines : Int
  chars : Int
  tables : Array[TomlTable]
  keys : Array[TomlKey]
  issues : Array[TomlIssue]
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
    "tomlskill",
    about="Inspect and normalize simple TOML-style config as a portable WASIp1 CLI.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "json",
        long="json",
        about="write compact JSON instead of Markdown",
      ),
      @argparse.FlagArg(
        "format",
        long="format",
        about="write normalized simple TOML instead of an inspection report",
      ),
      @argparse.FlagArg(
        "raw",
        long="raw",
        about="with --get, write only the raw value",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input TOML file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write output to a guest-visible file",
      ),
      @argparse.OptionArg(
        "get",
        long="get",
        about="dotted key path to extract, such as package.name",
      ),
      @argparse.OptionArg(
        "section",
        short='s',
        long="section",
        about="report section to print: summary, tables, keys, or issues",
      ),
      @argparse.OptionArg(
        "limit",
        long="limit",
        about="maximum rows to include per section",
        default_values=["40"],
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "toml",
        about="TOML words; stdin is used when omitted",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("tomlskill: failed to read argv: \{err}", 2)
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
fn values(matches : @argparse.Matches, name : String) -> Array[String] {
  matches.values.get(name).unwrap_or([])
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
fn read_input(matches : @argparse.Matches) -> String {
  let inline = values(matches, "toml")
  match option(matches, "file") {
    Some(path) => {
      if !inline.is_empty() {
        die("tomlskill: use either --file or inline TOML, not both", 2)
      }
      @miniio.read_text_file(path) catch {
        err => die("tomlskill: failed to read \{path}: \{err}", 1)
      }
    }
    None =>
      if inline.is_empty() {
        @miniio.stdin.read_all().text() catch {
          err => die("tomlskill: failed to read stdin: \{err}", 1)
        }
      } else {
        inline.join(" ")
      }
  }
}

///|
fn write_output(text : String, matches : @argparse.Matches) -> Unit {
  let output = if text.has_suffix("\n") { text } else { text + "\n" }
  match option(matches, "output") {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("tomlskill: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("tomlskill: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn line_count(text : String) -> Int {
  if text.is_empty() {
    return 0
  }
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  if text.has_suffix("\n") {
    count
  } else {
    count + 1
  }
}

///|
fn find_unquoted(text : String, needle : Char) -> Int? {
  let mut quote = '\u{0}'
  let mut escaped = false
  let mut pos = 0
  while pos < text.length() {
    guard text.get_char(pos) is Some(ch) else { break }
    if quote != '\u{0}' {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == quote {
        quote = '\u{0}'
      }
    } else if ch == '"' || ch == '\'' {
      quote = ch
    } else if ch == needle {
      return Some(pos)
    }
    pos += ch.utf16_len()
  }
  None
}

///|
fn strip_comment(line : String) -> String {
  match find_unquoted(line, '#') {
    Some(pos) => line[:pos].to_owned().trim().to_owned()
    None => line.trim().to_owned()
  }
}

///|
fn push_issue(
  issues : Array[TomlIssue],
  severity : String,
  line : Int,
  message : String,
) -> Unit {
  issues.push(TomlIssue::{ severity, line, message })
}

///|
fn parse_table(
  line : String,
  line_no : Int,
  issues : Array[TomlIssue],
) -> TomlTable? {
  if line.has_prefix("[[") && line.has_suffix("]]") {
    let name = line[2:line.length() - 2].to_owned().trim().to_owned()
    if name.is_empty() {
      push_issue(issues, "medium", line_no, "empty array table name")
      None
    } else {
      Some(TomlTable::{ line: line_no, name, array: true })
    }
  } else if line.has_prefix("[") && line.has_suffix("]") {
    let name = line[1:line.length() - 1].to_owned().trim().to_owned()
    if name.is_empty() {
      push_issue(issues, "medium", line_no, "empty table name")
      None
    } else {
      Some(TomlTable::{ line: line_no, name, array: false })
    }
  } else {
    None
  }
}

///|
fn infer_kind(value : String) -> String {
  let trimmed = value.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed.is_empty() {
    "empty"
  } else if (trimmed.has_prefix("\"") && trimmed.has_suffix("\"")) ||
    (trimmed.has_prefix("'") && trimmed.has_suffix("'")) {
    "string"
  } else if lower == "true" || lower == "false" {
    "boolean"
  } else if trimmed.has_prefix("[") {
    "array"
  } else if trimmed.has_prefix("{") {
    "inline-table"
  } else if looks_number(trimmed) {
    "number"
  } else if looks_date(trimmed) {
    "date"
  } else {
    "bare"
  }
}

///|
fn looks_number(text : String) -> Bool {
  let mut digit = false
  for ch in text {
    if ch.is_ascii_digit() {
      digit = true
    } else if ch == '-' || ch == '+' || ch == '.' || ch == '_' {
      ()
    } else {
      return false
    }
  }
  digit
}

///|
fn looks_date(text : String) -> Bool {
  text.length() >= 10 &&
  text.get_char(4) == Some('-') &&
  text.get_char(7) == Some('-')
}

///|
fn full_path(table : String, key : String) -> String {
  if table.is_empty() {
    key
  } else {
    table + "." + key
  }
}

///|
fn parse_key(
  line : String,
  line_no : Int,
  table : String,
  table_line : Int,
  issues : Array[TomlIssue],
) -> TomlKey? {
  match find_unquoted(line, '=') {
    Some(pos) if pos > 0 => {
      let name = line[:pos].to_owned().trim().to_owned()
      let value = line[pos + 1:].to_owned().trim().to_owned()
      if name.is_empty() {
        push_issue(issues, "medium", line_no, "empty key name")
        None
      } else if value.is_empty() {
        push_issue(issues, "medium", line_no, "empty value for key: \{name}")
        Some(TomlKey::{
          line: line_no,
          table,
          table_line,
          name,
          path: full_path(table, name),
          kind: "empty",
          value,
        })
      } else {
        Some(TomlKey::{
          line: line_no,
          table,
          table_line,
          name,
          path: full_path(table, name),
          kind: infer_kind(value),
          value,
        })
      }
    }
    Some(_) => {
      push_issue(issues, "medium", line_no, "empty key name")
      None
    }
    None => {
      push_issue(issues, "low", line_no, "unrecognized non-empty line")
      None
    }
  }
}

///|
fn analyze(text : String) -> TomlReport {
  let report = TomlReport::{
    lines: line_count(text),
    chars: text.char_length(),
    tables: [],
    keys: [],
    issues: [],
  }
  let seen_tables : Map[String, Int] = {}
  let seen_keys : Map[String, Int] = {}
  let mut current_table = ""
  let mut current_table_line = 0
  let mut current_table_array = false
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  for index in 0..<lines.length() {
    let line_no = index + 1
    let line = strip_comment(lines[index])
    if line.is_empty() {
      continue
    }
    match parse_table(line, line_no, report.issues) {
      Some(table) => {
        if !table.array {
          match seen_tables.get(table.name) {
            Some(first_line) =>
              push_issue(
                report.issues,
                "medium",
                line_no,
                "duplicate table: \{table.name} first seen on line \{first_line}",
              )
            None => seen_tables[table.name] = line_no
          }
        }
        current_table = table.name
        current_table_line = table.line
        current_table_array = table.array
        report.tables.push(table)
      }
      None =>
        match
          parse_key(
            line,
            line_no,
            current_table,
            current_table_line,
            report.issues,
          ) {
          Some(key) => {
            let duplicate_id = if current_table_array {
              key.path + "@" + key.table_line.to_string()
            } else {
              key.path
            }
            match seen_keys.get(duplicate_id) {
              Some(first_line) =>
                push_issue(
                  report.issues,
                  "medium",
                  line_no,
                  "duplicate key: \{key.path} first seen on line \{first_line}",
                )
              None => seen_keys[duplicate_id] = line_no
            }
            report.keys.push(key)
          }
          None => ()
        }
    }
  }
  report
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn table_json(table : TomlTable) -> Json {
  Json::object({
    "array": Json::boolean(table.array),
    "line": int_json(table.line),
    "name": Json::string(table.name),
  })
}

///|
fn key_json(key : TomlKey) -> Json {
  Json::object({
    "kind": Json::string(key.kind),
    "line": int_json(key.line),
    "name": Json::string(key.name),
    "path": Json::string(key.path),
    "table": Json::string(key.table),
    "value": Json::string(key.value),
  })
}

///|
fn issue_json(issue : TomlIssue) -> Json {
  Json::object({
    "line": int_json(issue.line),
    "message": Json::string(issue.message),
    "severity": Json::string(issue.severity),
  })
}

///|
fn report_json(report : TomlReport) -> String {
  Json::object({
    "chars": int_json(report.chars),
    "issues": Json::array([ for issue in report.issues => issue_json(issue) ]),
    "keys": Json::array([ for key in report.keys => key_json(key) ]),
    "lines": int_json(report.lines),
    "tables": Json::array([ for table in report.tables => table_json(table) ]),
  }).stringify()
}

///|
fn escape_cell(text : String) -> String {
  text.replace(old="|", new="\\|").replace(old="\n", new=" ")
}

///|
fn write_summary(out : StringBuilder, report : TomlReport) -> Unit {
  out.write_string("- lines: \{report.lines}\n")
  out.write_string("- chars: \{report.chars}\n")
  out.write_string("- tables: \{report.tables.length()}\n")
  out.write_string("- keys: \{report.keys.length()}\n")
  out.write_string("- issues: \{report.issues.length()}\n")
}

///|
fn write_tables(out : StringBuilder, report : TomlReport, limit : Int) -> Unit {
  out.write_string("## Tables\n\n")
  if report.tables.is_empty() {
    out.write_string("_No tables found._\n")
  } else {
    out.write_string("| line | table | kind |\n|---|---|---|\n")
    let cap = report.tables.length().min(limit)
    for index in 0..<cap {
      let table = report.tables[index]
      let kind = if table.array { "array" } else { "table" }
      out.write_string(
        "| \{table.line} | \{escape_cell(table.name)} | \{kind} |\n",
      )
    }
  }
}

///|
fn write_keys(out : StringBuilder, report : TomlReport, limit : Int) -> Unit {
  out.write_string("## Keys\n\n")
  if report.keys.is_empty() {
    out.write_string("_No keys found._\n")
  } else {
    out.write_string("| line | path | kind | value |\n|---|---|---|---|\n")
    let cap = report.keys.length().min(limit)
    for index in 0..<cap {
      let key = report.keys[index]
      out.write_string(
        "| \{key.line} | \{escape_cell(key.path)} | \{key.kind} | \{escape_cell(key.value)} |\n",
      )
    }
  }
}

///|
fn write_issues(out : StringBuilder, report : TomlReport, limit : Int) -> Unit {
  out.write_string("## Issues\n\n")
  if report.issues.is_empty() {
    out.write_string("_No structural issues found._\n")
  } else {
    out.write_string("| severity | line | message |\n|---|---|---|\n")
    let cap = report.issues.length().min(limit)
    for index in 0..<cap {
      let issue = report.issues[index]
      out.write_string(
        "| \{issue.severity} | \{issue.line} | \{escape_cell(issue.message)} |\n",
      )
    }
  }
}

///|
fn render_markdown(report : TomlReport, matches : @argparse.Matches) -> String {
  let limit = int_value(matches, "limit", 40).clamp(min=0, max=1000)
  let out = StringBuilder()
  match option(matches, "section") {
    Some("summary") => write_summary(out, report)
    Some("tables") => write_tables(out, report, limit)
    Some("keys") => write_keys(out, report, limit)
    Some("issues") => write_issues(out, report, limit)
    Some(section) => die("tomlskill: unknown section \{section}", 2)
    None => {
      out.write_string("# TOML Skill\n\n")
      write_summary(out, report)
      out.write_string("\n")
      write_tables(out, report, limit)
      out.write_string("\n")
      write_keys(out, report, limit)
      out.write_string("\n")
      write_issues(out, report, limit)
    }
  }
  out.to_string()
}

///|
fn lookup_key(report : TomlReport, path : String) -> TomlKey? {
  for key in report.keys {
    if key.path == path || (key.table.is_empty() && key.name == path) {
      return Some(key)
    }
  }
  None
}

///|
fn get_json(path : String, found : TomlKey?) -> String {
  match found {
    Some(key) =>
      Json::object({
        "found": Json::boolean(true),
        "kind": Json::string(key.kind),
        "line": int_json(key.line),
        "path": Json::string(key.path),
        "value": Json::string(key.value),
      }).stringify()
    None =>
      Json::object({ "found": Json::boolean(false), "path": Json::string(path) }).stringify()
  }
}

///|
fn render_get(
  report : TomlReport,
  path : String,
  matches : @argparse.Matches,
) -> String {
  let found = lookup_key(report, path)
  if flag(matches, "json") {
    get_json(path, found)
  } else {
    match found {
      Some(key) =>
        if flag(matches, "raw") {
          key.value
        } else {
          "\{key.path} = \{key.value}"
        }
      None => die("tomlskill: key not found: \{path}", 1)
    }
  }
}

///|
fn append_keys_for_table(
  out : StringBuilder,
  report : TomlReport,
  table_line : Int,
) -> Unit {
  for key in report.keys {
    if key.table_line == table_line {
      out.write_string("\{key.name} = \{key.value}\n")
    }
  }
}

///|
fn format_toml(report : TomlReport) -> String {
  let out = StringBuilder()
  append_keys_for_table(out, report, 0)
  for table in report.tables {
    if !out.is_empty() {
      out.write_string("\n")
    }
    if table.array {
      out.write_string("[[\{table.name}]]\n")
    } else {
      out.write_string("[\{table.name}]\n")
    }
    append_keys_for_table(out, report, table.line)
  }
  out.to_string()
}

///|
fn validate_modes(matches : @argparse.Matches) -> Unit {
  if flag(matches, "raw") && option(matches, "get") is None {
    die("tomlskill: --raw requires --get", 2)
  }
  if flag(matches, "format") && option(matches, "section") is Some(_) {
    die("tomlskill: --format cannot be combined with --section", 2)
  }
  if flag(matches, "format") && option(matches, "get") is Some(_) {
    die("tomlskill: --format cannot be combined with --get", 2)
  }
}

///|
fn main {
  let matches = parse()
  validate_modes(matches)
  let report = analyze(read_input(matches))
  let output = match option(matches, "get") {
    Some(path) => render_get(report, path, matches)
    None =>
      if flag(matches, "json") {
        report_json(report)
      } else if flag(matches, "format") {
        format_toml(report)
      } else {
        render_markdown(report, matches)
      }
  }
  write_output(output, matches)
}
