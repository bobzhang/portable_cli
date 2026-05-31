///|
struct DataOptions {
  file : String?
  delimiter : String
  has_header : Bool
  max_rows : Int
  sample_rows : Int
  as_json : Bool
  output : String?
}

///|
struct ColumnStats {
  name : String
  mut empty : Int
  mut non_empty : Int
  mut int_count : Int
  mut number_count : Int
  mut bool_count : Int
  mut max_len : Int
}

///|
struct DatasetSummary {
  delimiter : String
  rows_scanned : Int
  columns : Int
  truncated : Bool
  column_stats : Array[ColumnStats]
  sample : Array[Array[String]]
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
    "datascout",
    about="Summarize CSV/TSV-like data into bounded Markdown or JSON.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "json",
        long="json",
        about="write compact JSON instead of Markdown",
      ),
      @argparse.FlagArg(
        "no-header",
        long="no-header",
        about="treat the first row as data and synthesize column names",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input delimited file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "delimiter",
        short='d',
        long="delimiter",
        about="delimiter: auto, comma, tab, semicolon, or a single character",
        default_values=["auto"],
      ),
      @argparse.OptionArg(
        "max-rows",
        long="max-rows",
        about="maximum data rows to scan",
        default_values=["1000"],
      ),
      @argparse.OptionArg(
        "sample",
        short='s',
        long="sample",
        about="sample rows to include in the report",
        default_values=["5"],
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
    err => die("datascout: failed to read argv: \{err}", 2)
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
fn options_from_matches(matches : @argparse.Matches) -> DataOptions {
  {
    file: option(matches, "file"),
    delimiter: value(matches, "delimiter", "auto"),
    has_header: !flag(matches, "no-header"),
    max_rows: int_value(matches, "max-rows", 1000).clamp(min=1, max=100000),
    sample_rows: int_value(matches, "sample", 5).clamp(min=0, max=100),
    as_json: flag(matches, "json"),
    output: option(matches, "output"),
  }
}

///|
fn read_input(options : DataOptions) -> String {
  match options.file {
    Some(path) =>
      @miniio.read_text_file(path) catch {
        err => die("datascout: failed to read \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdin.read_all().text() catch {
        err => die("datascout: failed to read stdin: \{err}", 1)
      }
  }
}

///|
fn strip_cr(line : StringView) -> String {
  let text = line.to_owned()
  if text.has_suffix("\r") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn delimiter_text(delimiter : Char) -> String {
  match delimiter {
    ',' => "comma"
    '\t' => "tab"
    ';' => "semicolon"
    _ => delimiter.to_string()
  }
}

///|
fn parse_delimiter(name : String, input : String) -> Char {
  let normalized = name.to_lower()
  match normalized {
    "comma" | "," => ','
    "tab" | "\\t" => '\t'
    "semicolon" | ";" => ';'
    "auto" => sniff_delimiter(input)
    _ =>
      if name.char_length() == 1 {
        match name.get_char(0) {
          Some(ch) => ch
          None => ','
        }
      } else {
        die(
          "datascout: invalid --delimiter: \{name} (expected auto, comma, tab, semicolon, or one character)",
          2,
        )
      }
  }
}

///|
fn count_char(text : String, needle : Char) -> Int {
  let mut count = 0
  for ch in text {
    if ch == needle {
      count += 1
    }
  }
  count
}

///|
fn sniff_delimiter(input : String) -> Char {
  let mut first = ""
  for raw in input.split("\n") {
    let line = strip_cr(raw)
    if line.trim() != "" {
      first = line
      break
    }
  }
  let comma = count_char(first, ',')
  let tab = count_char(first, '\t')
  let semicolon = count_char(first, ';')
  if tab > comma && tab >= semicolon {
    '\t'
  } else if semicolon > comma {
    ';'
  } else {
    ','
  }
}

///|
fn parse_row(line : String, delimiter : Char) -> Array[String] {
  let cells : Array[String] = []
  let mut cell = StringBuilder()
  let mut quoted = false
  let mut i = 0
  while i < line.length() {
    match line.get_char(i) {
      Some('"') =>
        if quoted && i + 1 < line.length() && line.get_char(i + 1) == Some('"') {
          cell.write_char('"')
          i += 2
        } else {
          quoted = !quoted
          i += 1
        }
      Some(ch) if ch == delimiter && !quoted => {
        cells.push(cell.to_string())
        cell = StringBuilder()
        i += 1
      }
      Some(ch) => {
        cell.write_char(ch)
        i += 1
      }
      None => i += 1
    }
  }
  cells.push(cell.to_string())
  cells
}

///|
fn column_name(index : Int) -> String {
  "column_\{index + 1}"
}

///|
fn ensure_width(row : Array[String], width : Int) -> Array[String] {
  let out : Array[String] = []
  for index in 0..<width {
    out.push(row.get(index).unwrap_or(""))
  }
  out
}

///|
fn make_column_stats(headers : Array[String]) -> Array[ColumnStats] {
  [
    for index, name in headers => {
      ColumnStats::{
        name: if name.trim() == "" {
          column_name(index)
        } else {
          name
        },
        empty: 0,
        non_empty: 0,
        int_count: 0,
        number_count: 0,
        bool_count: 0,
        max_len: 0,
      }
    }
  ]
}

///|
fn is_int(value : String) -> Bool {
  let _ = @string.parse_int(value) catch { _ => return false }
  true
}

///|
fn is_number(value : String) -> Bool {
  let _ = @string.parse_double(value) catch { _ => return false }
  true
}

///|
fn is_bool(value : String) -> Bool {
  let normalized = value.to_lower()
  normalized == "true" || normalized == "false"
}

///|
fn update_stats(stats : Array[ColumnStats], row : Array[String]) -> Unit {
  for index in 0..<stats.length() {
    let value = row.get(index).unwrap_or("").trim().to_owned()
    let stat = stats[index]
    let len = value.char_length()
    if len > stat.max_len {
      stat.max_len = len
    }
    if value == "" {
      stat.empty += 1
    } else {
      stat.non_empty += 1
      if is_int(value) {
        stat.int_count += 1
      }
      if is_number(value) {
        stat.number_count += 1
      }
      if is_bool(value) {
        stat.bool_count += 1
      }
    }
  }
}

///|
fn inferred_type(stat : ColumnStats) -> String {
  if stat.non_empty == 0 {
    "empty"
  } else if stat.bool_count == stat.non_empty {
    "boolean"
  } else if stat.int_count == stat.non_empty {
    "integer"
  } else if stat.number_count == stat.non_empty {
    "number"
  } else {
    "string"
  }
}

///|
fn summarize(input : String, options : DataOptions) -> DatasetSummary {
  let delimiter = parse_delimiter(options.delimiter, input)
  let rows : Array[Array[String]] = []
  for raw in input.split("\n") {
    let line = strip_cr(raw)
    if line.trim() != "" {
      rows.push(parse_row(line, delimiter))
    }
  }
  if rows.is_empty() {
    return DatasetSummary::{
      delimiter: delimiter_text(delimiter),
      rows_scanned: 0,
      columns: 0,
      truncated: false,
      column_stats: [],
      sample: [],
    }
  }
  let headers = if options.has_header {
    rows[0]
  } else {
    [
      for index in 0..<rows[0].length() => column_name(index)
    ]
  }
  let stats = make_column_stats(headers)
  let start = if options.has_header { 1 } else { 0 }
  let sample : Array[Array[String]] = []
  let mut scanned = 0
  let mut truncated = false
  for index in start..<rows.length() {
    if scanned >= options.max_rows {
      truncated = true
      break
    }
    let row = ensure_width(rows[index], stats.length())
    update_stats(stats, row)
    if sample.length() < options.sample_rows {
      sample.push(row)
    }
    scanned += 1
  }
  DatasetSummary::{
    delimiter: delimiter_text(delimiter),
    rows_scanned: scanned,
    columns: stats.length(),
    truncated,
    column_stats: stats,
    sample,
  }
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn stat_json(stat : ColumnStats) -> Json {
  Json::object({
    "empty": int_json(stat.empty),
    "max_len": int_json(stat.max_len),
    "name": Json::string(stat.name),
    "non_empty": int_json(stat.non_empty),
    "type": Json::string(inferred_type(stat)),
  })
}

///|
fn row_json(row : Array[String]) -> Json {
  Json::array([ for cell in row => Json::string(cell) ])
}

///|
fn summary_json(summary : DatasetSummary) -> String {
  Json::object({
    "columns": int_json(summary.columns),
    "delimiter": Json::string(summary.delimiter),
    "rows_scanned": int_json(summary.rows_scanned),
    "sample": Json::array([ for row in summary.sample => row_json(row) ]),
    "schema": Json::array(
      [
        for stat in summary.column_stats => stat_json(stat)
      ],
    ),
    "truncated": Json::boolean(summary.truncated),
  }).stringify()
}

///|
fn escape_cell(text : String) -> String {
  text.replace(old="|", new="\\|").replace(old="\n", new=" ")
}

///|
fn summary_markdown(summary : DatasetSummary) -> String {
  let out = StringBuilder()
  out.write_string("# Data Scout\n\n")
  out.write_string("- delimiter: \{summary.delimiter}\n")
  out.write_string("- rows scanned: \{summary.rows_scanned}\n")
  out.write_string("- columns: \{summary.columns}\n")
  out.write_string("- truncated: \{summary.truncated}\n")
  out.write_string("\n## Schema\n\n")
  if summary.column_stats.is_empty() {
    out.write_string("_No rows found._\n")
  } else {
    out.write_string("| column | type | non-empty | empty | max len |\n")
    out.write_string("|---|---|---:|---:|---:|\n")
    for stat in summary.column_stats {
      out.write_string(
        "| \{escape_cell(stat.name)} | \{inferred_type(stat)} | \{stat.non_empty} | \{stat.empty} | \{stat.max_len} |\n",
      )
    }
  }
  out.write_string("\n## Sample\n\n")
  if summary.sample.is_empty() || summary.column_stats.is_empty() {
    out.write_string("_No sample rows._\n")
  } else {
    out.write_string("|")
    for stat in summary.column_stats {
      out.write_string(" \{escape_cell(stat.name)} |")
    }
    out.write_string("\n|")
    for _ in summary.column_stats {
      out.write_string("---|")
    }
    out.write_string("\n")
    for row in summary.sample {
      out.write_string("|")
      for cell in row {
        out.write_string(" \{escape_cell(cell)} |")
      }
      out.write_string("\n")
    }
  }
  out.to_string()
}

///|
fn write_output(text : String, options : DataOptions) -> Unit {
  let output = if text.has_suffix("\n") { text } else { text + "\n" }
  match options.output {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("datascout: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("datascout: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let options = options_from_matches(parse())
  let summary = summarize(read_input(options), options)
  let output = if options.as_json {
    summary_json(summary)
  } else {
    summary_markdown(summary)
  }
  write_output(output, options)
}
