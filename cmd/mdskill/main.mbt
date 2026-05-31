///|
struct Heading {
  line : Int
  level : Int
  text : String
  slug : String
}

///|
struct LinkItem {
  line : Int
  text : String
  target : String
}

///|
struct TaskItem {
  line : Int
  done : Bool
  text : String
}

///|
struct CodeFence {
  start_line : Int
  end_line : Int
  language : String
  lines : Int
}

///|
struct FrontMatterItem {
  key : String
  value : String
}

///|
struct MarkdownIssue {
  severity : String
  line : Int
  message : String
}

///|
struct MarkdownReport {
  lines : Int
  mut words : Int
  chars : Int
  frontmatter : Array[FrontMatterItem]
  headings : Array[Heading]
  links : Array[LinkItem]
  tasks : Array[TaskItem]
  fences : Array[CodeFence]
  issues : Array[MarkdownIssue]
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
    "mdskill",
    about="Inspect Markdown structure as a portable WASIp1 CLI.",
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
        about="input Markdown file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write output to a guest-visible file",
      ),
      @argparse.OptionArg(
        "section",
        short='s',
        long="section",
        about="Markdown section to print: summary, frontmatter, outline, links, tasks, code, or issues",
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
        "markdown",
        about="Markdown words; stdin is used when omitted",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("mdskill: failed to read argv: \{err}", 2)
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
  let inline = values(matches, "markdown")
  match option(matches, "file") {
    Some(path) => {
      if !inline.is_empty() {
        die("mdskill: use either --file or inline Markdown, not both", 2)
      }
      @miniio.read_text_file(path) catch {
        err => die("mdskill: failed to read \{path}: \{err}", 1)
      }
    }
    None =>
      if inline.is_empty() {
        @miniio.stdin.read_all().text() catch {
          err => die("mdskill: failed to read stdin: \{err}", 1)
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
        err => die("mdskill: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("mdskill: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn word_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '\''
}

///|
fn count_words_line(line : String) -> Int {
  let mut count = 0
  let mut in_word = false
  for ch in line {
    if word_char(ch) {
      if !in_word {
        count += 1
      }
      in_word = true
    } else {
      in_word = false
    }
  }
  count
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
fn slugify(text : String) -> String {
  let out = StringBuilder()
  let mut pending_dash = false
  for ch in text.to_lower() {
    if ch.is_ascii_alphabetic() || ch.is_ascii_digit() {
      if pending_dash && !out.is_empty() {
        out.write_char('-')
      }
      out.write_char(ch)
      pending_dash = false
    } else if ch.is_ascii_whitespace() || ch == '-' || ch == '_' {
      pending_dash = true
    }
  }
  out.to_string()
}

///|
fn heading_from_line(line : String, line_no : Int) -> Heading? {
  let trimmed = line.trim().to_owned()
  let mut level = 0
  while level < trimmed.length() && level < 6 {
    match trimmed.get_char(level) {
      Some('#') => level += 1
      _ => break
    }
  }
  if level == 0 || level >= trimmed.length() {
    return None
  }
  match trimmed.get_char(level) {
    Some(ch) if ch.is_ascii_whitespace() => {
      let text = trimmed[level:].to_owned().trim().to_owned()
      if text.is_empty() {
        None
      } else {
        Some(Heading::{ line: line_no, level, text, slug: slugify(text) })
      }
    }
    _ => None
  }
}

///|
fn task_from_line(line : String, line_no : Int) -> TaskItem? {
  let trimmed = line.trim().to_owned()
  if trimmed.has_prefix("- [ ] ") || trimmed.has_prefix("* [ ] ") {
    Some(TaskItem::{
      line: line_no,
      done: false,
      text: trimmed[6:].to_owned().trim().to_owned(),
    })
  } else if trimmed.has_prefix("- [x] ") ||
    trimmed.has_prefix("- [X] ") ||
    trimmed.has_prefix("* [x] ") ||
    trimmed.has_prefix("* [X] ") {
    Some(TaskItem::{
      line: line_no,
      done: true,
      text: trimmed[6:].to_owned().trim().to_owned(),
    })
  } else {
    None
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
fn collect_links(line : String, line_no : Int, links : Array[LinkItem]) -> Unit {
  let mut pos = 0
  while pos < line.length() {
    guard find_from(line, "[", pos) is Some(open) else { break }
    let is_image = open > 0 && line.get_char(open - 1) == Some('!')
    guard find_from(line, "](", open + 1) is Some(close_text) else { break }
    guard find_from(line, ")", close_text + 2) is Some(close_target) else {
      break
    }
    if !is_image {
      let text = line[open + 1:close_text].to_owned()
      let target = line[close_text + 2:close_target].to_owned()
      links.push(LinkItem::{ line: line_no, text, target })
    }
    pos = close_target + 1
  }
}

///|
fn frontmatter_item(line : String) -> FrontMatterItem? {
  match line.find(":") {
    Some(pos) if pos > 0 => {
      let key = line[:pos].to_owned().trim().to_owned()
      let value = line[pos + 1:].to_owned().trim().to_owned()
      if key.is_empty() {
        None
      } else {
        Some(FrontMatterItem::{ key, value })
      }
    }
    _ => None
  }
}

///|
fn fence_marker(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  if trimmed.has_prefix("```") {
    Some("```")
  } else if trimmed.has_prefix("~~~") {
    Some("~~~")
  } else {
    None
  }
}

///|
fn fence_language(line : String, marker : String) -> String {
  line.trim().to_owned()[marker.length():].to_owned().trim().to_owned()
}

///|
fn push_issue(
  issues : Array[MarkdownIssue],
  severity : String,
  line : Int,
  message : String,
) -> Unit {
  issues.push(MarkdownIssue::{ severity, line, message })
}

///|
fn seen_slug(slugs : Array[String], slug : String) -> Bool {
  for item in slugs {
    if item == slug {
      return true
    }
  }
  false
}

///|
fn analyze(text : String) -> MarkdownReport {
  let report = MarkdownReport::{
    lines: line_count(text),
    words: 0,
    chars: text.char_length(),
    frontmatter: [],
    headings: [],
    links: [],
    tasks: [],
    fences: [],
    issues: [],
  }
  let slugs : Array[String] = []
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  let mut in_frontmatter = false
  let mut frontmatter_closed = false
  let mut in_fence = false
  let mut fence_start = 0
  let mut fence_marker_text = ""
  let mut fence_language_text = ""
  let mut fence_lines = 0
  for index in 0..<lines.length() {
    let line_no = index + 1
    let line = lines[index]
    let trimmed = line.trim().to_owned()
    if index == 0 && trimmed == "---" {
      in_frontmatter = true
      continue
    }
    if in_frontmatter {
      if trimmed == "---" {
        in_frontmatter = false
        frontmatter_closed = true
      } else {
        match frontmatter_item(line) {
          Some(item) => report.frontmatter.push(item)
          None => ()
        }
      }
      continue
    }
    match fence_marker(line) {
      Some(marker) if !in_fence => {
        in_fence = true
        fence_start = line_no
        fence_marker_text = marker
        fence_language_text = fence_language(line, marker)
        fence_lines = 0
        continue
      }
      Some(marker) if in_fence && marker == fence_marker_text => {
        in_fence = false
        report.fences.push(CodeFence::{
          start_line: fence_start,
          end_line: line_no,
          language: fence_language_text,
          lines: fence_lines,
        })
        fence_start = 0
        fence_marker_text = ""
        fence_language_text = ""
        fence_lines = 0
        continue
      }
      _ => ()
    }
    if in_fence {
      fence_lines += 1
      continue
    }
    report.words += count_words_line(line)
    match heading_from_line(line, line_no) {
      Some(heading) => {
        if seen_slug(slugs, heading.slug) {
          push_issue(
            report.issues,
            "medium",
            line_no,
            "duplicate heading slug: \{heading.slug}",
          )
        } else if !heading.slug.is_empty() {
          slugs.push(heading.slug)
        }
        report.headings.push(heading)
      }
      None => ()
    }
    match task_from_line(line, line_no) {
      Some(task) => report.tasks.push(task)
      None => ()
    }
    collect_links(line, line_no, report.links)
  }
  if in_frontmatter && !frontmatter_closed {
    push_issue(report.issues, "low", 1, "front matter was not closed")
  }
  if in_fence {
    push_issue(
      report.issues,
      "medium",
      fence_start,
      "code fence was not closed",
    )
  }
  for link in report.links {
    if link.target.trim().is_empty() {
      push_issue(report.issues, "medium", link.line, "link target is empty")
    }
  }
  report
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn heading_json(heading : Heading) -> Json {
  Json::object({
    "level": int_json(heading.level),
    "line": int_json(heading.line),
    "slug": Json::string(heading.slug),
    "text": Json::string(heading.text),
  })
}

///|
fn link_json(link : LinkItem) -> Json {
  Json::object({
    "line": int_json(link.line),
    "target": Json::string(link.target),
    "text": Json::string(link.text),
  })
}

///|
fn task_json(task : TaskItem) -> Json {
  Json::object({
    "done": Json::boolean(task.done),
    "line": int_json(task.line),
    "text": Json::string(task.text),
  })
}

///|
fn fence_json(fence : CodeFence) -> Json {
  Json::object({
    "end_line": int_json(fence.end_line),
    "language": Json::string(fence.language),
    "lines": int_json(fence.lines),
    "start_line": int_json(fence.start_line),
  })
}

///|
fn frontmatter_json(item : FrontMatterItem) -> Json {
  Json::object({
    "key": Json::string(item.key),
    "value": Json::string(item.value),
  })
}

///|
fn issue_json(issue : MarkdownIssue) -> Json {
  Json::object({
    "line": int_json(issue.line),
    "message": Json::string(issue.message),
    "severity": Json::string(issue.severity),
  })
}

///|
fn report_json(report : MarkdownReport) -> String {
  Json::object({
    "chars": int_json(report.chars),
    "code_fences": Json::array(
      [
        for fence in report.fences => fence_json(fence)
      ],
    ),
    "frontmatter": Json::array(
      [
        for item in report.frontmatter => frontmatter_json(item)
      ],
    ),
    "headings": Json::array(
      [
        for heading in report.headings => heading_json(heading)
      ],
    ),
    "issues": Json::array([ for issue in report.issues => issue_json(issue) ]),
    "lines": int_json(report.lines),
    "links": Json::array([ for link in report.links => link_json(link) ]),
    "tasks": Json::array([ for task in report.tasks => task_json(task) ]),
    "words": int_json(report.words),
  }).stringify()
}

///|
fn escape_cell(text : String) -> String {
  text.replace(old="|", new="\\|").replace(old="\n", new=" ")
}

///|
fn write_summary(out : StringBuilder, report : MarkdownReport) -> Unit {
  let done = report.tasks.fold(init=0, (acc, task) => {
    if task.done {
      acc + 1
    } else {
      acc
    }
  })
  out.write_string("- lines: \{report.lines}\n")
  out.write_string("- words: \{report.words}\n")
  out.write_string("- chars: \{report.chars}\n")
  out.write_string("- headings: \{report.headings.length()}\n")
  out.write_string("- links: \{report.links.length()}\n")
  out.write_string("- tasks: \{report.tasks.length()} (\{done} done)\n")
  out.write_string("- code fences: \{report.fences.length()}\n")
  out.write_string("- issues: \{report.issues.length()}\n")
}

///|
fn write_frontmatter(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
  out.write_string("## Front Matter\n\n")
  if report.frontmatter.is_empty() {
    out.write_string("_No front matter found._\n")
  } else {
    out.write_string("| key | value |\n|---|---|\n")
    let cap = report.frontmatter.length().min(limit)
    for index in 0..<cap {
      let item = report.frontmatter[index]
      out.write_string(
        "| \{escape_cell(item.key)} | \{escape_cell(item.value)} |\n",
      )
    }
  }
}

///|
fn write_outline(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
  out.write_string("## Outline\n\n")
  if report.headings.is_empty() {
    out.write_string("_No headings found._\n")
  } else {
    let cap = report.headings.length().min(limit)
    for index in 0..<cap {
      let heading = report.headings[index]
      let prefix = "#".repeat(heading.level)
      out.write_string(
        "- L\{heading.line}: \{prefix} \{heading.text} (`#\{heading.slug}`)\n",
      )
    }
  }
}

///|
fn write_links(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
  out.write_string("## Links\n\n")
  if report.links.is_empty() {
    out.write_string("_No links found._\n")
  } else {
    out.write_string("| line | text | target |\n|---|---|---|\n")
    let cap = report.links.length().min(limit)
    for index in 0..<cap {
      let link = report.links[index]
      out.write_string(
        "| \{link.line} | \{escape_cell(link.text)} | \{escape_cell(link.target)} |\n",
      )
    }
  }
}

///|
fn write_tasks(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
  out.write_string("## Tasks\n\n")
  if report.tasks.is_empty() {
    out.write_string("_No task list items found._\n")
  } else {
    out.write_string("| state | line | text |\n|---|---|---|\n")
    let cap = report.tasks.length().min(limit)
    for index in 0..<cap {
      let task = report.tasks[index]
      let state = if task.done { "done" } else { "open" }
      out.write_string(
        "| \{state} | \{task.line} | \{escape_cell(task.text)} |\n",
      )
    }
  }
}

///|
fn write_code(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
  out.write_string("## Code Fences\n\n")
  if report.fences.is_empty() {
    out.write_string("_No code fences found._\n")
  } else {
    out.write_string("| language | start | end | lines |\n|---|---|---|---|\n")
    let cap = report.fences.length().min(limit)
    for index in 0..<cap {
      let fence = report.fences[index]
      out.write_string(
        "| \{escape_cell(fence.language)} | \{fence.start_line} | \{fence.end_line} | \{fence.lines} |\n",
      )
    }
  }
}

///|
fn write_issues(
  out : StringBuilder,
  report : MarkdownReport,
  limit : Int,
) -> Unit {
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
fn render_markdown(
  report : MarkdownReport,
  matches : @argparse.Matches,
) -> String {
  let limit = int_value(matches, "limit", 40).clamp(min=0, max=1000)
  let out = StringBuilder()
  match option(matches, "section") {
    Some("summary") => write_summary(out, report)
    Some("frontmatter") => write_frontmatter(out, report, limit)
    Some("outline") => write_outline(out, report, limit)
    Some("links") => write_links(out, report, limit)
    Some("tasks") => write_tasks(out, report, limit)
    Some("code") => write_code(out, report, limit)
    Some("issues") => write_issues(out, report, limit)
    Some(section) => die("mdskill: unknown section \{section}", 2)
    None => {
      out.write_string("# Markdown Skill\n\n")
      write_summary(out, report)
      out.write_string("\n")
      write_frontmatter(out, report, limit)
      out.write_string("\n")
      write_outline(out, report, limit)
      out.write_string("\n")
      write_links(out, report, limit)
      out.write_string("\n")
      write_tasks(out, report, limit)
      out.write_string("\n")
      write_code(out, report, limit)
      out.write_string("\n")
      write_issues(out, report, limit)
    }
  }
  out.to_string()
}

///|
fn main {
  let matches = parse()
  let report = analyze(read_input(matches))
  let output = if flag(matches, "json") {
    report_json(report)
  } else {
    render_markdown(report, matches)
  }
  write_output(output, matches)
}
