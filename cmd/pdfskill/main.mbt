///|
struct PdfObjectHit {
  number : Int
  generation : Int
  offset : Int
}

///|
struct PdfInput {
  path : String
  data : Bytes
}

///|
struct PdfScan {
  path : String
  input_bytes : Int
  version : String
  startxref : Int
  object_hits : Array[PdfObjectHit]
  eof_markers : Int
  object_candidates : Int
  page_candidates : Int
  stream_candidates : Int
  xref_tokens : Int
  encrypted : Bool
  javascript : Int
  active_actions : Int
  embedded_files : Int
  acroform : Bool
  xfa : Bool
  images : Int
  object_streams : Int
  linearized : Bool
}

///|
enum PdfSkillCommand {
  Brief(String, Bool, String?)
  Doctor(String)
  Map(String, Int)
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
    "pdfskill",
    about="Portable PDF triage for agent skills, powered by pdflite/reader and miniio.",
    version="0.1.0",
    subcommand_required=true,
    disable_help_subcommand=true,
    subcommands=[
      @argparse.Command(
        "brief",
        about="Write an agent-readable Markdown or JSON triage report.",
        flags=[
          @argparse.FlagArg(
            "json",
            long="json",
            about="write compact JSON instead of Markdown",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "output",
            short='o',
            long="output",
            about="write the report to a guest-visible file",
          ),
        ],
        positionals=[
          @argparse.PositionArg(
            "input",
            about="input PDF path",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "doctor",
        about="Run quick structural checks and print pass/warn lines.",
        positionals=[
          @argparse.PositionArg(
            "input",
            about="input PDF path",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "map",
        about="List indirect object candidates with byte offsets.",
        options=[
          @argparse.OptionArg(
            "limit",
            long="limit",
            about="maximum object candidates to print",
            default_values=["40"],
          ),
        ],
        positionals=[
          @argparse.PositionArg(
            "input",
            about="input PDF path",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
    ],
  )
}

///|
fn parse() -> PdfSkillCommand {
  let args = @miniio.args_get() catch {
    err => die("pdfskill: failed to read argv: \{err}", 2)
  }
  let env = @miniio.get_env_vars() catch { _ => {} }
  let matches = command().parse(argv=args[1:], env~) catch {
    err => die(err.to_string(), 2)
  }
  match matches.subcommand {
    Some(("brief", sub)) =>
      Brief(
        required_value(sub, "input"),
        flag(sub, "json"),
        option(sub, "output"),
      )
    Some(("doctor", sub)) => Doctor(required_value(sub, "input"))
    Some(("map", sub)) =>
      Map(required_value(sub, "input"), int_value(sub, "limit", 40))
    Some((name, _)) => die("pdfskill: unexpected subcommand: \{name}", 2)
    None => die("pdfskill: missing subcommand", 2)
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
  let raw = value(matches, name, fallback.to_string())
  @string.parse_int(raw) catch {
    _ => die("pdfskill: invalid integer for --\{name}: \{raw}", 2)
  }
}

///|
fn required_value(matches : @argparse.Matches, name : String) -> String {
  match matches.values.get(name) {
    Some([item]) => item
    _ => die("pdfskill: missing required argument \{name}", 2)
  }
}

///|
fn read_pdf_bytes(path : String) -> Bytes {
  @miniio.read_file(path).binary() catch {
    err => die("pdfskill: failed to read \{path}: \{err}", 1)
  }
}

///|
fn read_pdf_input(path : String) -> PdfInput {
  { path, data: read_pdf_bytes(path) }
}

///|
fn match_at(data : BytesView, offset : Int, needle : BytesView) -> Bool {
  if offset < 0 || offset + needle.length() > data.length() {
    return false
  }
  for i in 0..<needle.length() {
    if data[offset + i] != needle[i] {
      return false
    }
  }
  true
}

///|
fn count_occurrences(data : BytesView, pattern : String) -> Int {
  let needle = @utf8.encode(pattern)
  let mut count = 0
  let mut index = 0
  while index + needle.length() <= data.length() {
    if match_at(data, index, needle) {
      count += 1
      index += needle.length()
    } else {
      index += 1
    }
  }
  count
}

///|
fn is_pdf_name_body(byte : Byte) -> Bool {
  !@core.pdf_is_whitespace_or_delimiter_byte(byte.to_int())
}

///|
fn count_pdf_name(data : BytesView, name : String) -> Int {
  let needle = @utf8.encode(name)
  let mut count = 0
  let mut index = 0
  while index + needle.length() <= data.length() {
    if match_at(data, index, needle) {
      let after = index + needle.length()
      if after == data.length() || !is_pdf_name_body(data[after]) {
        count += 1
      }
      index = after
    } else {
      index += 1
    }
  }
  count
}

///|
fn parse_uint_at(data : BytesView, start : Int) -> (Int, Int)? {
  if start >= data.length() || !@core.pdf_is_digit_byte(data[start].to_int()) {
    return None
  }
  let mut index = start
  let mut value = 0
  while index < data.length() && @core.pdf_is_digit_byte(data[index].to_int()) {
    value = value * 10 + data[index].to_int() - b'0'.to_int()
    index += 1
  }
  Some((value, index))
}

///|
fn skip_spaces(data : BytesView, start : Int) -> Int {
  let mut index = start
  while index < data.length() &&
        @core.pdf_is_whitespace_byte(data[index].to_int()) {
    index += 1
  }
  index
}

///|
fn token_boundary_before(data : BytesView, index : Int) -> Bool {
  index == 0 ||
  @core.pdf_is_whitespace_or_delimiter_byte(data[index - 1].to_int())
}

///|
fn token_boundary_after(data : BytesView, index : Int) -> Bool {
  index >= data.length() ||
  @core.pdf_is_whitespace_or_delimiter_byte(data[index].to_int())
}

///|
fn scan_objects(data : BytesView, limit : Int) -> Array[PdfObjectHit] {
  let hits : Array[PdfObjectHit] = []
  let object_token = @utf8.encode("obj")
  let cap = if limit < 0 { 0 } else { limit }
  let mut index = 0
  while index < data.length() && hits.length() < cap {
    if !token_boundary_before(data, index) {
      index += 1
      continue
    }
    match parse_uint_at(data, index) {
      Some((number, after_number)) => {
        let gen_start = skip_spaces(data, after_number)
        match parse_uint_at(data, gen_start) {
          Some((generation, after_generation)) => {
            let obj_start = skip_spaces(data, after_generation)
            let obj_end = obj_start + object_token.length()
            if match_at(data, obj_start, object_token) &&
              token_boundary_after(data, obj_end) {
              hits.push({ number, generation, offset: index })
              index = obj_end
            } else {
              index += 1
            }
          }
          None => index += 1
        }
      }
      None => index += 1
    }
  }
  hits
}

///|
fn object_scan_limit() -> Int {
  1000000
}

///|
fn limit_object_hits(
  hits : Array[PdfObjectHit],
  limit : Int,
) -> Array[PdfObjectHit] {
  let cap = if limit < 0 {
    0
  } else if limit < hits.length() {
    limit
  } else {
    hits.length()
  }
  let out : Array[PdfObjectHit] = []
  for i in 0..<cap {
    out.push(hits[i])
  }
  out
}

///|
fn scan_pdf(input : PdfInput) -> PdfScan {
  let version = @reader.pdf_read_header_from_bytes(input.data) catch {
    err =>
      die(
        "pdfskill: failed to read PDF header for \{input.path}: " +
        @core.pdf_error_summary(err),
        1,
      )
  }
  let startxref = @reader.pdf_read_startxref_position(input.data) catch {
    _ => -1
  }
  let object_hits = scan_objects(input.data, object_scan_limit())
  {
    path: input.path,
    input_bytes: input.data.length(),
    version: version.major.to_string() + "." + version.minor.to_string(),
    startxref,
    object_hits,
    eof_markers: count_occurrences(input.data, "%%EOF"),
    object_candidates: object_hits.length(),
    page_candidates: count_pdf_name(input.data, "/Page"),
    stream_candidates: count_occurrences(input.data, "stream"),
    xref_tokens: count_occurrences(input.data, "xref"),
    encrypted: count_pdf_name(input.data, "/Encrypt") > 0,
    javascript: count_pdf_name(input.data, "/JavaScript") +
    count_pdf_name(input.data, "/JS"),
    active_actions: count_pdf_name(input.data, "/OpenAction") +
    count_pdf_name(input.data, "/AA") +
    count_pdf_name(input.data, "/Launch"),
    embedded_files: count_pdf_name(input.data, "/EmbeddedFile") +
    count_pdf_name(input.data, "/Filespec"),
    acroform: count_pdf_name(input.data, "/AcroForm") > 0,
    xfa: count_pdf_name(input.data, "/XFA") > 0,
    images: count_pdf_name(input.data, "/Image"),
    object_streams: count_pdf_name(input.data, "/ObjStm"),
    linearized: count_pdf_name(input.data, "/Linearized") > 0,
  }
}

///|
fn risk_label(scan : PdfScan) -> String {
  if scan.encrypted {
    "encrypted"
  } else if scan.javascript > 0 || scan.active_actions > 0 {
    "active-content"
  } else if scan.embedded_files > 0 || scan.xfa {
    "review"
  } else if scan.startxref < 0 || scan.eof_markers == 0 {
    "malformed"
  } else {
    "low"
  }
}

///|
fn bool_text(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn startxref_text(scan : PdfScan) -> String {
  if scan.startxref < 0 {
    "missing"
  } else {
    scan.startxref.to_string()
  }
}

///|
fn int_json(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn scan_json(scan : PdfScan) -> String {
  Json::object({
    "acroform": Json::boolean(scan.acroform),
    "active_actions": int_json(scan.active_actions),
    "bytes": int_json(scan.input_bytes),
    "embedded_files": int_json(scan.embedded_files),
    "encrypted": Json::boolean(scan.encrypted),
    "eof_markers": int_json(scan.eof_markers),
    "images": int_json(scan.images),
    "javascript": int_json(scan.javascript),
    "linearized": Json::boolean(scan.linearized),
    "object_candidates": int_json(scan.object_candidates),
    "object_streams": int_json(scan.object_streams),
    "page_candidates": int_json(scan.page_candidates),
    "path": Json::string(scan.path),
    "risk": Json::string(risk_label(scan)),
    "startxref": int_json(scan.startxref),
    "stream_candidates": int_json(scan.stream_candidates),
    "version": Json::string(scan.version),
    "xfa": Json::boolean(scan.xfa),
    "xref_tokens": int_json(scan.xref_tokens),
  }).stringify() +
  "\n"
}

///|
fn scan_markdown(scan : PdfScan) -> String {
  (
    $|# PDF Skill Brief
    $|
    $|- path: `\{scan.path}`
    $|- version: \{scan.version}
    $|- bytes: \{scan.input_bytes}
    $|- startxref: \{startxref_text(scan)}
    $|- eof markers: \{scan.eof_markers}
    $|- object candidates: \{scan.object_candidates}
    $|- page candidates: \{scan.page_candidates}
    $|- stream candidates: \{scan.stream_candidates}
    $|- xref tokens: \{scan.xref_tokens}
    $|- encrypted: \{bool_text(scan.encrypted)}
    $|- javascript names: \{scan.javascript}
    $|- active action names: \{scan.active_actions}
    $|- embedded file names: \{scan.embedded_files}
    $|- acroform: \{bool_text(scan.acroform)}
    $|- xfa: \{bool_text(scan.xfa)}
    $|- image names: \{scan.images}
    $|- object streams: \{scan.object_streams}
    $|- linearized: \{bool_text(scan.linearized)}
    $|- risk: \{risk_label(scan)}
    $|
    $|## Agent Notes
    $|
    $|- This is byte-level triage, not page rendering or full semantic extraction.
    $|- Escalate to a renderer/parser when signatures, forms, layout, or attachments matter.
    $|
  )
}

///|
fn write_text_output(path : String?, text : String) -> Unit {
  match path {
    Some(output) =>
      @miniio.write_text_file(output, text) catch {
        err => die("pdfskill: failed to write \{output}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(text) catch {
        err => die("pdfskill: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn run_brief(input : String, as_json : Bool, output : String?) -> Unit {
  let scan = scan_pdf(read_pdf_input(input))
  write_text_output(
    output,
    if as_json {
      scan_json(scan)
    } else {
      scan_markdown(scan)
    },
  )
}

///|
fn doctor_line(kind : String, label : String, value : String) -> String {
  "\{kind} \{label}: \{value}"
}

///|
fn run_doctor(input : String) -> Unit {
  let scan = scan_pdf(read_pdf_input(input))
  let startxref_line = if scan.startxref >= 0 {
    doctor_line("ok", "startxref", scan.startxref.to_string())
  } else {
    doctor_line("warn", "startxref", "missing")
  }
  let eof_line = if scan.eof_markers > 0 {
    doctor_line("ok", "eof", scan.eof_markers.to_string())
  } else {
    doctor_line("warn", "eof", "missing")
  }
  let objects_line = if scan.object_candidates > 0 {
    doctor_line("ok", "objects", scan.object_candidates.to_string())
  } else {
    doctor_line("warn", "objects", "none detected")
  }
  let out =
    $|pdfskill doctor: \{input}
    $|ok header: PDF \{scan.version}
    $|\{startxref_line}
    $|\{eof_line}
    $|\{objects_line}
    $|info risk: \{risk_label(scan)}
    $|
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}

///|
fn run_map(input : String, limit : Int) -> Unit {
  let pdf = read_pdf_input(input)
  let scan = scan_pdf(pdf)
  let hits = limit_object_hits(scan.object_hits, limit)
  let mut out =
    $|# PDF Object Map
    $|
    $|- path: `\{input}`
    $|- listed: \{hits.length()}
    $|
    $|| object | generation | offset |
    $||---:|---:|---:|
    $|
  for hit in hits {
    out += (
      $|| \{hit.number} | \{hit.generation} | \{hit.offset} |
      $|
    )
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}

///|
fn main {
  match parse() {
    Brief(input, as_json, output) => run_brief(input, as_json, output)
    Doctor(input) => run_doctor(input)
    Map(input, limit) => run_map(input, limit)
  }
}
