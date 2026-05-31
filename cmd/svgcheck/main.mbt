///|
struct TagCount {
  name : String
  count : Int
}

///|
struct SvgIssue {
  severity : String
  line : Int
  message : String
}

///|
struct SvgSummary {
  lines : Int
  chars : Int
  mut elements : Int
  mut root_seen : Bool
  mut width : String
  mut height : String
  mut view_box : String
  mut scripts : Int
  mut images : Int
  mut foreign_objects : Int
  mut animations : Int
  tags : Map[String, Int]
  issues : Array[SvgIssue]
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
    "svgcheck",
    about="Inspect SVG structure and risky features as a portable WASIp1 CLI.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "json",
        long="json",
        about="write compact JSON instead of Markdown",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input SVG file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write output to a guest-visible file",
      ),
      @argparse.OptionArg(
        "limit",
        long="limit",
        about="maximum tag counts and issues to include",
        default_values=["40"],
      ),
      @argparse.OptionArg(
        "fail-on",
        long="fail-on",
        about="exit non-zero when issues at or above this severity are found: high, medium, low, or none",
        default_values=["none"],
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("svgcheck: failed to read argv: \{err}", 2)
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
fn read_input(matches : @argparse.Matches) -> String {
  match option(matches, "file") {
    Some(path) =>
      @miniio.read_text_file(path) catch {
        err => die("svgcheck: failed to read \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdin.read_all().text() catch {
        err => die("svgcheck: failed to read stdin: \{err}", 1)
      }
  }
}

///|
fn write_output(text : String, matches : @argparse.Matches) -> Unit {
  let output = if text.has_suffix("\n") { text } else { text + "\n" }
  match option(matches, "output") {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("svgcheck: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("svgcheck: failed to write stdout: \{err}", 1)
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
fn find_from(text : String, needle : String, start : Int) -> Int? {
  if start >= text.length() {
    return None
  }
  match text[start:].find(needle) {
    Some(pos) => Some(start + pos)
    None => None
  }
}

///|
fn tag_name(token : String) -> String {
  let mut pos = 0
  while pos < token.length() {
    match token.get_char(pos) {
      Some('<') | Some('/') | Some('?') | Some('!') => pos += 1
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      _ => break
    }
  }
  let start = pos
  while pos < token.length() {
    match token.get_char(pos) {
      Some(ch) if ch.is_ascii_alphabetic() ||
        ch.is_ascii_digit() ||
        ch == '-' ||
        ch == ':' => pos += ch.utf16_len()
      _ => break
    }
  }
  token[start:pos].to_owned().to_lower()
}

///|
fn is_opening_tag(token : String) -> Bool {
  let trimmed = token.trim().to_owned()
  trimmed.has_prefix("<") &&
  !trimmed.has_prefix("</") &&
  !trimmed.has_prefix("<!--") &&
  !trimmed.has_prefix("<?") &&
  !trimmed.has_prefix("<!")
}

///|
fn quoted_attr(token : String, name : String) -> String {
  for quote in ['"', '\''] {
    let pattern = name + "=" + quote.to_string()
    match token.find(pattern) {
      Some(start) => {
        let value_start = start + pattern.length()
        match find_from(token, quote.to_string(), value_start) {
          Some(end) => return token[value_start:end].to_owned()
          None => ()
        }
      }
      None => ()
    }
  }
  ""
}

///|
fn attr_value(token : String, name : String) -> String {
  let exact = quoted_attr(token, name)
  if exact != "" {
    exact
  } else {
    quoted_attr(token.to_lower(), name.to_lower())
  }
}

///|
fn push_issue(
  issues : Array[SvgIssue],
  severity : String,
  line : Int,
  message : String,
) -> Unit {
  issues.push(SvgIssue::{ severity, line, message })
}

///|
fn contains_event_handler(token_lower : String) -> Bool {
  token_lower.contains(" onload=") ||
  token_lower.contains(" onerror=") ||
  token_lower.contains(" onclick=") ||
  token_lower.contains(" onmouseover=") ||
  token_lower.contains(" onbegin=") ||
  token_lower.contains(" onend=") ||
  token_lower.contains(" onrepeat=") ||
  token_lower.contains(" onfocus=") ||
  token_lower.contains(" onblur=")
}

///|
fn inspect_tag(summary : SvgSummary, token : String, line_no : Int) -> Unit {
  if !is_opening_tag(token) {
    return
  }
  let name = tag_name(token)
  if name.is_empty() {
    return
  }
  let lower = token.to_lower()
  summary.elements += 1
  summary.tags[name] = summary.tags.get(name).unwrap_or(0) + 1
  if name == "svg" && !summary.root_seen {
    summary.root_seen = true
    summary.width = attr_value(token, "width")
    summary.height = attr_value(token, "height")
    summary.view_box = attr_value(token, "viewBox")
  } else if name == "script" {
    summary.scripts += 1
    push_issue(summary.issues, "high", line_no, "script element present")
  } else if name == "image" {
    summary.images += 1
  } else if name == "foreignobject" {
    summary.foreign_objects += 1
    push_issue(summary.issues, "high", line_no, "foreignObject can embed HTML")
  } else if name.has_prefix("animate") {
    summary.animations += 1
  }
  if contains_event_handler(lower) {
    push_issue(
      summary.issues,
      "high",
      line_no,
      "event handler attribute present",
    )
  }
  if lower.contains("javascript:") {
    push_issue(summary.issues, "high", line_no, "javascript URL present")
  }
  if lower.contains("href=\"http") ||
    lower.contains("href='http") ||
    lower.contains("xlink:href=\"http") ||
    lower.contains("xlink:href='http") ||
    lower.contains("url(http") {
    push_issue(summary.issues, "medium", line_no, "external reference present")
  }
}

///|
fn analyze(text : String) -> SvgSummary {
  let summary = SvgSummary::{
    lines: line_count(text),
    chars: text.char_length(),
    elements: 0,
    root_seen: false,
    width: "",
    height: "",
    view_box: "",
    scripts: 0,
    images: 0,
    foreign_objects: 0,
    animations: 0,
    tags: {},
    issues: [],
  }
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  for index in 0..<lines.length() {
    let line = lines[index]
    let mut pos = 0
    while pos < line.length() {
      guard find_from(line, "<", pos) is Some(open) else { break }
      guard find_from(line, ">", open + 1) is Some(close) else {
        push_issue(summary.issues, "medium", index + 1, "unterminated tag")
        break
      }
      inspect_tag(summary, line[open:close + 1].to_owned(), index + 1)
      pos = close + 1
    }
  }
  if !summary.root_seen {
    push_issue(summary.issues, "high", 1, "missing root svg element")
  }
  summary
}

///|
fn tag_counts(summary : SvgSummary) -> Array[TagCount] {
  let counts : Array[TagCount] = []
  for entry in summary.tags.to_array() {
    counts.push(TagCount::{ name: entry.0, count: entry.1 })
  }
  counts.sort_by((left, right) => {
    let by_count = right.count.compare(left.count)
    if by_count != 0 {
      by_count
    } else {
      left.name.compare(right.name)
    }
  })
  counts
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn issue_json(issue : SvgIssue) -> Json {
  Json::object({
    "line": int_json(issue.line),
    "message": Json::string(issue.message),
    "severity": Json::string(issue.severity),
  })
}

///|
fn tag_count_json(count : TagCount) -> Json {
  Json::object({
    "count": int_json(count.count),
    "name": Json::string(count.name),
  })
}

///|
fn report_json(summary : SvgSummary) -> String {
  Json::object({
    "animations": int_json(summary.animations),
    "chars": int_json(summary.chars),
    "elements": int_json(summary.elements),
    "foreign_objects": int_json(summary.foreign_objects),
    "height": Json::string(summary.height),
    "images": int_json(summary.images),
    "issues": Json::array([ for issue in summary.issues => issue_json(issue) ]),
    "lines": int_json(summary.lines),
    "root_seen": Json::boolean(summary.root_seen),
    "scripts": int_json(summary.scripts),
    "tags": Json::array(
      [
        for count in tag_counts(summary) => tag_count_json(count)
      ],
    ),
    "view_box": Json::string(summary.view_box),
    "width": Json::string(summary.width),
  }).stringify()
}

///|
fn escape_cell(text : String) -> String {
  text.replace(old="|", new="\\|").replace(old="\n", new=" ")
}

///|
fn report_markdown(summary : SvgSummary, matches : @argparse.Matches) -> String {
  let limit = int_value(matches, "limit", 40).clamp(min=0, max=1000)
  let out = StringBuilder()
  out.write_string("# SVG Check\n\n")
  out.write_string("- lines: \{summary.lines}\n")
  out.write_string("- chars: \{summary.chars}\n")
  out.write_string("- elements: \{summary.elements}\n")
  out.write_string(
    "- root svg: \{if summary.root_seen { "yes" } else { "no" }}\n",
  )
  out.write_string(
    "- width: \{if summary.width == "" { "unknown" } else { summary.width }}\n",
  )
  out.write_string(
    "- height: \{if summary.height == "" { "unknown" } else { summary.height }}\n",
  )
  out.write_string(
    "- viewBox: \{if summary.view_box == "" { "unknown" } else { summary.view_box }}\n",
  )
  out.write_string("- scripts: \{summary.scripts}\n")
  out.write_string("- images: \{summary.images}\n")
  out.write_string("- foreignObject: \{summary.foreign_objects}\n")
  out.write_string("- animations: \{summary.animations}\n")
  out.write_string("- issues: \{summary.issues.length()}\n")
  out.write_string("\n## Tag Counts\n\n")
  let counts = tag_counts(summary)
  if counts.is_empty() {
    out.write_string("_No elements found._\n")
  } else {
    out.write_string("| tag | count |\n|---|---|\n")
    let cap = counts.length().min(limit)
    for index in 0..<cap {
      let count = counts[index]
      out.write_string("| \{escape_cell(count.name)} | \{count.count} |\n")
    }
  }
  out.write_string("\n## Issues\n\n")
  if summary.issues.is_empty() {
    out.write_string("_No risk signals found._\n")
  } else {
    out.write_string("| severity | line | message |\n|---|---|---|\n")
    let cap = summary.issues.length().min(limit)
    for index in 0..<cap {
      let issue = summary.issues[index]
      out.write_string(
        "| \{issue.severity} | \{issue.line} | \{escape_cell(issue.message)} |\n",
      )
    }
  }
  out.to_string()
}

///|
fn severity_rank(severity : String) -> Int {
  match severity {
    "high" => 3
    "medium" => 2
    "low" => 1
    "none" => 0
    _ => -1
  }
}

///|
fn validate_fail_on(value : String) -> Int {
  let normalized = value.to_lower()
  let rank = severity_rank(normalized)
  if rank < 0 {
    die("svgcheck: --fail-on must be high, medium, low, or none", 2)
  }
  rank
}

///|
fn should_fail(summary : SvgSummary, threshold : Int) -> Bool {
  if threshold <= 0 {
    return false
  }
  for issue in summary.issues {
    if severity_rank(issue.severity) >= threshold {
      return true
    }
  }
  false
}

///|
fn main {
  let matches = parse()
  let summary = analyze(read_input(matches))
  let output = if flag(matches, "json") {
    report_json(summary)
  } else {
    report_markdown(summary, matches)
  }
  write_output(output, matches)
  let threshold = validate_fail_on(value(matches, "fail-on", "none"))
  if should_fail(summary, threshold) {
    @miniio.exit(1)
    panic()
  }
}
