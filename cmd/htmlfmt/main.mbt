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
    "htmlfmt",
    about="Format and inspect HTML with bobzhang/html_parser as a portable WASIp1 CLI.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "compact",
        short='c',
        long="compact",
        about="write compact HTML instead of pretty HTML",
      ),
      @argparse.FlagArg(
        "document",
        short='d',
        long="document",
        about="parse input as a full HTML document; default is fragment mode",
      ),
      @argparse.FlagArg(
        "sanitize",
        long="sanitize",
        about="apply html_parser's default sanitizer before formatting",
      ),
      @argparse.FlagArg(
        "strict",
        long="strict",
        about="fail on the first parse error",
      ),
      @argparse.FlagArg(
        "inspect",
        long="inspect",
        about="write an outline, link, metadata, and accessibility report instead of formatted HTML",
      ),
      @argparse.FlagArg(
        "text",
        long="text",
        about="write clean extracted text instead of formatted HTML",
      ),
      @argparse.FlagArg(
        "markdown",
        long="markdown",
        about="write Markdown converted from the parsed HTML",
      ),
      @argparse.FlagArg(
        "html-passthrough",
        long="html-passthrough",
        about="with --markdown, preserve unsupported HTML instead of dropping it",
      ),
      @argparse.FlagArg(
        "json",
        long="json",
        about="with --inspect, write compact JSON instead of Markdown",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write command output to a guest-visible file",
      ),
      @argparse.OptionArg(
        "indent",
        short='i',
        long="indent",
        about="pretty-print indentation",
        default_values=["2"],
      ),
      @argparse.OptionArg(
        "limit",
        long="limit",
        about="maximum headings, links, metadata, and issues to include in reports",
        default_values=["40"],
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "html",
        about="HTML fragment words; stdin is used when omitted",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("htmlfmt: failed to read argv: \{err}", 2)
  }
  let env = @miniio.get_env_vars() catch { _ => {} }
  command().parse(argv=args[1:], env~) catch {
    err => die(err.to_string(), 2)
  }
}

///|
fn output_mode_count(matches : @argparse.Matches) -> Int {
  let mut count = 0
  if flag(matches, "inspect") {
    count += 1
  }
  if flag(matches, "text") {
    count += 1
  }
  if flag(matches, "markdown") {
    count += 1
  }
  count
}

///|
fn validate_output_modes(matches : @argparse.Matches) -> Unit {
  if output_mode_count(matches) > 1 {
    die("htmlfmt: choose only one of --inspect, --text, or --markdown", 2)
  }
  if flag(matches, "json") && !flag(matches, "inspect") {
    die("htmlfmt: --json requires --inspect", 2)
  }
  if flag(matches, "html-passthrough") && !flag(matches, "markdown") {
    die("htmlfmt: --html-passthrough requires --markdown", 2)
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
  let inline = values(matches, "html")
  match option(matches, "file") {
    Some(path) => {
      if !inline.is_empty() {
        die("htmlfmt: use either --file or inline HTML, not both", 2)
      }
      @miniio.read_text_file(path) catch {
        err => die("htmlfmt: failed to read \{path}: \{err}", 1)
      }
    }
    None =>
      if inline.is_empty() {
        @miniio.stdin.read_all().text() catch {
          err => die("htmlfmt: failed to read stdin: \{err}", 1)
        }
      } else {
        inline.join(" ")
      }
  }
}

///|
fn html_error_message(error : @html_parser.HtmlError) -> String {
  match error {
    StrictMode(parse_error) =>
      "strict parse error: \{parse_error.code}: \{parse_error.message}"
    InvalidSerialization(message) => message
    UnsafeHtml(message) => message
    SelectorError(message) => message
  }
}

///|
fn parse_html(
  input : String,
  matches : @argparse.Matches,
) -> @html_parser.ParsedHtml {
  let sanitize = flag(matches, "sanitize")
  let strict = flag(matches, "strict")
  try {
    if flag(matches, "document") {
      @html_parser.parse(input, sanitize~, strict~)
    } else {
      @html_parser.parse_fragment(input, sanitize~, strict~)
    }
  } catch {
    err => die("htmlfmt: \{html_error_message(err)}", 1)
  }
}

///|
fn format_html(input : String, matches : @argparse.Matches) -> String {
  let pretty = !flag(matches, "compact")
  let indent = int_value(matches, "indent", 2).clamp(min=0, max=8)
  parse_html(input, matches).to_html(pretty~, indent_size=indent) catch {
    err => die("htmlfmt: \{html_error_message(err)}", 1)
  }
}

///|
fn text_html(input : String, matches : @argparse.Matches) -> String {
  parse_html(input, matches).to_text(
    separator="\n",
    strip=true,
    separator_blocks_only=true,
  )
}

///|
fn markdown_html(input : String, matches : @argparse.Matches) -> String {
  parse_html(input, matches).to_markdown(
    html_passthrough=flag(matches, "html-passthrough"),
  ) catch {
    err => die("htmlfmt: \{html_error_message(err)}", 1)
  }
}

///|
struct Heading {
  level : Int
  text : String
}

///|
struct LinkItem {
  text : String
  href : String
}

///|
struct MetaItem {
  key : String
  value : String
}

///|
struct HtmlIssue {
  severity : String
  message : String
}

///|
struct HtmlReport {
  root_kind : String
  mut elements : Int
  mut text_chars : Int
  headings : Array[Heading]
  links : Array[LinkItem]
  metadata : Array[MetaItem]
  mut images : Int
  mut images_missing_alt : Int
  mut scripts : Int
  mut forms : Int
  issues : Array[HtmlIssue]
}

///|
fn attr(node : @html_parser.Node, name : String) -> String? {
  match node.attrs().get(name) {
    Some(Some(value)) => Some(value)
    Some(None) => Some("")
    None => None
  }
}

///|
fn push_issue(
  issues : Array[HtmlIssue],
  limit : Int,
  severity : String,
  message : String,
) -> Unit {
  if issues.length() < limit {
    issues.push(HtmlIssue::{ severity, message })
  }
}

///|
fn heading_level(name : String) -> Int {
  match name {
    "h1" => 1
    "h2" => 2
    "h3" => 3
    "h4" => 4
    "h5" => 5
    "h6" => 6
    _ => 0
  }
}

///|
fn clean_text(text : String) -> String {
  text
  .split("\n")
  .map(part => part.trim())
  .filter(part => !part.is_empty())
  .to_array()
  .join(" ")
}

///|
fn meta_key(node : @html_parser.Node) -> String? {
  match attr(node, "property") {
    Some(value) if value != "" => Some(value)
    _ =>
      match attr(node, "name") {
        Some(value) if value != "" => Some(value)
        _ =>
          match attr(node, "charset") {
            Some(value) if value != "" => Some("charset")
            _ => None
          }
      }
  }
}

///|
fn meta_value(node : @html_parser.Node) -> String {
  match attr(node, "content") {
    Some(value) => value
    None =>
      match attr(node, "charset") {
        Some(value) => value
        None => ""
      }
  }
}

///|
fn add_meta(
  metadata : Array[MetaItem],
  limit : Int,
  key : String,
  value : String,
) -> Unit {
  if metadata.length() < limit {
    metadata.push(MetaItem::{ key, value })
  }
}

///|
fn node_kind_text(kind : @html_parser.NodeKind) -> String {
  match kind {
    Document => "Document"
    Fragment => "Fragment"
    Element => "Element"
    Text => "Text"
    Comment => "Comment"
    Doctype => "Doctype"
  }
}

///|
fn walk_report(
  node : @html_parser.Node,
  report : HtmlReport,
  limit : Int,
) -> Unit {
  match node.kind() {
    Element => {
      report.elements += 1
      let name = node.name().to_lower()
      let level = heading_level(name)
      if level > 0 && report.headings.length() < limit {
        report.headings.push(Heading::{ level, text: clean_text(node.text()) })
      } else if name == "a" {
        match attr(node, "href") {
          Some(href) if href != "" => {
            if report.links.length() < limit {
              report.links.push(LinkItem::{
                text: clean_text(node.text()),
                href,
              })
            }
            if clean_text(node.text()) == "" {
              push_issue(
                report.issues,
                limit,
                "medium",
                "link with href has no text: \{href}",
              )
            }
          }
          _ => ()
        }
      } else if name == "img" {
        report.images += 1
        match attr(node, "alt") {
          Some(_) => ()
          None => {
            report.images_missing_alt += 1
            let src = attr(node, "src").unwrap_or("")
            push_issue(
              report.issues,
              limit,
              "medium",
              "image missing alt text: \{src}",
            )
          }
        }
      } else if name == "script" {
        report.scripts += 1
        let src = attr(node, "src").unwrap_or("inline")
        push_issue(report.issues, limit, "info", "script present: \{src}")
      } else if name == "form" {
        report.forms += 1
      } else if name == "title" {
        add_meta(report.metadata, limit, "title", clean_text(node.text()))
      } else if name == "meta" {
        match meta_key(node) {
          Some(key) => add_meta(report.metadata, limit, key, meta_value(node))
          None => ()
        }
      }
    }
    Text => report.text_chars += node.data().char_length()
    _ => ()
  }
  for child in node.children() {
    walk_report(child, report, limit)
  }
}

///|
fn analyze_html(input : String, matches : @argparse.Matches) -> HtmlReport {
  let parsed = parse_html(input, matches)
  let root = parsed.root
  let report = HtmlReport::{
    root_kind: node_kind_text(root.kind()),
    elements: 0,
    text_chars: 0,
    headings: [],
    links: [],
    metadata: [],
    images: 0,
    images_missing_alt: 0,
    scripts: 0,
    forms: 0,
    issues: [],
  }
  let limit = int_value(matches, "limit", 40).clamp(min=0, max=1000)
  walk_report(root, report, limit)
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
    "text": Json::string(heading.text),
  })
}

///|
fn link_json(link : LinkItem) -> Json {
  Json::object({
    "href": Json::string(link.href),
    "text": Json::string(link.text),
  })
}

///|
fn meta_json(meta : MetaItem) -> Json {
  Json::object({
    "key": Json::string(meta.key),
    "value": Json::string(meta.value),
  })
}

///|
fn issue_json(issue : HtmlIssue) -> Json {
  Json::object({
    "message": Json::string(issue.message),
    "severity": Json::string(issue.severity),
  })
}

///|
fn report_json(report : HtmlReport) -> String {
  Json::object({
    "elements": int_json(report.elements),
    "forms": int_json(report.forms),
    "headings": Json::array(
      [
        for heading in report.headings => heading_json(heading)
      ],
    ),
    "images": int_json(report.images),
    "images_missing_alt": int_json(report.images_missing_alt),
    "issues": Json::array([ for issue in report.issues => issue_json(issue) ]),
    "links": Json::array([ for link in report.links => link_json(link) ]),
    "metadata": Json::array([ for meta in report.metadata => meta_json(meta) ]),
    "root_kind": Json::string(report.root_kind),
    "scripts": int_json(report.scripts),
    "text_chars": int_json(report.text_chars),
  }).stringify()
}

///|
fn report_markdown(report : HtmlReport) -> String {
  let out = StringBuilder()
  out.write_string("# HTML Inspect\n\n")
  out.write_string("- root kind: \{report.root_kind}\n")
  out.write_string("- elements: \{report.elements}\n")
  out.write_string("- text chars: \{report.text_chars}\n")
  out.write_string("- headings: \{report.headings.length()}\n")
  out.write_string("- links: \{report.links.length()}\n")
  out.write_string("- images: \{report.images}\n")
  out.write_string("- images missing alt: \{report.images_missing_alt}\n")
  out.write_string("- scripts: \{report.scripts}\n")
  out.write_string("- forms: \{report.forms}\n")
  out.write_string("\n## Metadata\n\n")
  if report.metadata.is_empty() {
    out.write_string("_No metadata found._\n")
  } else {
    out.write_string("| key | value |\n|---|---|\n")
    for meta in report.metadata {
      out.write_string("| \{meta.key} | \{meta.value} |\n")
    }
  }
  out.write_string("\n## Outline\n\n")
  if report.headings.is_empty() {
    out.write_string("_No headings found._\n")
  } else {
    for heading in report.headings {
      let prefix = "#".repeat(heading.level)
      out.write_string("- \{prefix} \{heading.text}\n")
    }
  }
  out.write_string("\n## Links\n\n")
  if report.links.is_empty() {
    out.write_string("_No links found._\n")
  } else {
    out.write_string("| text | href |\n|---|---|\n")
    for link in report.links {
      out.write_string("| \{link.text} | \{link.href} |\n")
    }
  }
  out.write_string("\n## Issues\n\n")
  if report.issues.is_empty() {
    out.write_string("_No basic issues found._\n")
  } else {
    out.write_string("| severity | message |\n|---|---|\n")
    for issue in report.issues {
      out.write_string("| \{issue.severity} | \{issue.message} |\n")
    }
  }
  out.to_string()
}

///|
fn inspect_html(input : String, matches : @argparse.Matches) -> String {
  let report = analyze_html(input, matches)
  if flag(matches, "json") {
    report_json(report)
  } else {
    report_markdown(report)
  }
}

///|
fn write_output(text : String, matches : @argparse.Matches) -> Unit {
  let output = if text.has_suffix("\n") { text } else { text + "\n" }
  match option(matches, "output") {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("htmlfmt: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("htmlfmt: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let matches = parse()
  validate_output_modes(matches)
  let input = read_input(matches).trim().to_owned()
  let output = if flag(matches, "inspect") {
    inspect_html(input, matches)
  } else if flag(matches, "text") {
    text_html(input, matches)
  } else if flag(matches, "markdown") {
    markdown_html(input, matches)
  } else {
    format_html(input, matches)
  }
  write_output(output, matches)
}
