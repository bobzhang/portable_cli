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
struct PdfObjectSummary {
  hit : PdfObjectHit
  kind : String
  type_name : String
  subtype_name : String
  has_stream : Bool
  length : String
  filters : String
  note : String
}

///|
enum PdfSkillCommand {
  Brief(String, Bool, String?)
  Doctor(String)
  Map(String, Int)
  Objects(String, Int, String?, Bool)
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
      @argparse.Command(
        "objects",
        about="Parse and summarize indirect objects, dictionaries, and streams.",
        flags=[
          @argparse.FlagArg(
            "json",
            long="json",
            about="write compact JSON instead of Markdown",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "limit",
            long="limit",
            about="maximum matching objects to print",
            default_values=["40"],
          ),
          @argparse.OptionArg(
            "contains",
            long="contains",
            about="only include objects whose raw bytes or summary contain this text",
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
    Some(("objects", sub)) =>
      Objects(
        required_value(sub, "input"),
        int_value(sub, "limit", 40),
        option(sub, "contains"),
        flag(sub, "json"),
      )
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
fn find_occurrence_from(data : BytesView, start : Int, pattern : String) -> Int {
  let needle = @utf8.encode(pattern)
  let mut index = if start < 0 { 0 } else { start }
  while index + needle.length() <= data.length() {
    if match_at(data, index, needle) {
      return index
    }
    index += 1
  }
  -1
}

///|
fn pdf_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@utf8.encode(text))
}

///|
fn pdf_name_text(name : @core.PdfName) -> String {
  @utf8.decode_lossy(name.bytes())
}

///|
fn object_end_offset(data : BytesView, hit : PdfObjectHit) -> Int {
  let endobj = find_occurrence_from(data, hit.offset, "endobj")
  if endobj < 0 {
    -1
  } else {
    endobj + 6
  }
}

///|
fn object_view(input : PdfInput, hit : PdfObjectHit) -> BytesView? {
  let end = object_end_offset(input.data, hit)
  if end < 0 || end <= hit.offset {
    return None
  }
  let cursor = @core.byte_cursor_of_bytes(input.data)
  Some(cursor.view_at(hit.offset, end - hit.offset) catch { _ => return None })
}

///|
fn object_kind(object : @syntax.PdfObject) -> String {
  match object {
    PdfNull => "null"
    PdfBoolean(_) => "bool"
    PdfInteger(_) => "int"
    PdfReal(_) => "real"
    PdfString(_) => "string"
    PdfNameObject(_) => "name"
    PdfArray(_) => "array"
    PdfDictionary(_) => "dict"
    PdfStreamObject(_) => "stream"
    PdfIndirect(_) => "ref"
  }
}

///|
fn object_dictionary(object : @syntax.PdfObject) -> @syntax.PdfObject? {
  match object {
    PdfDictionary(_) => Some(object)
    PdfStreamObject(stream) => Some(stream.dictionary)
    _ => None
  }
}

///|
fn object_name_text(object : @syntax.PdfObject) -> String? {
  match object {
    PdfNameObject(name) => Some(pdf_name_text(name))
    _ => None
  }
}

///|
fn object_int_text(object : @syntax.PdfObject) -> String? {
  match object {
    PdfInteger(value) => Some(value.to_string())
    PdfIndirect(number) => Some("ref:\{number}")
    _ => None
  }
}

///|
fn lookup_object(dict : @syntax.PdfObject, key : String) -> @syntax.PdfObject? {
  dict.lookup_immediate(pdf_name(key))
}

///|
fn lookup_name_text(dict : @syntax.PdfObject, key : String) -> String {
  match lookup_object(dict, key) {
    Some(value) =>
      match object_name_text(value) {
        Some(name) => name
        None => "-"
      }
    None => "-"
  }
}

///|
fn lookup_length_text(dict : @syntax.PdfObject) -> String {
  match lookup_object(dict, "/Length") {
    Some(value) =>
      match object_int_text(value) {
        Some(text) => text
        None => "-"
      }
    None => "-"
  }
}

///|
fn join_strings(items : Array[String], separator : String) -> String {
  if items.length() == 0 {
    return "-"
  }
  let mut out = items[0]
  for i in 1..<items.length() {
    out += separator + items[i]
  }
  out
}

///|
fn append_filter_names(
  object : @syntax.PdfObject,
  output : Array[String],
) -> Unit {
  match object {
    PdfNameObject(name) => output.push(pdf_name_text(name))
    PdfArray(items) =>
      for item in items {
        append_filter_names(item, output)
      }
    _ => ()
  }
}

///|
fn lookup_filters_text(dict : @syntax.PdfObject) -> String {
  let filters : Array[String] = []
  match lookup_object(dict, "/Filter") {
    Some(value) => append_filter_names(value, filters)
    None => ()
  }
  join_strings(filters, ",")
}

///|
fn object_summary_from_parsed(
  hit : PdfObjectHit,
  object : @syntax.PdfObject,
  raw_has_stream : Bool,
) -> PdfObjectSummary {
  let dict = object_dictionary(object)
  let type_name = match dict {
    Some(value) => lookup_name_text(value, "/Type")
    None => "-"
  }
  let subtype_name = match dict {
    Some(value) => lookup_name_text(value, "/Subtype")
    None => "-"
  }
  let length = match dict {
    Some(value) => lookup_length_text(value)
    None => "-"
  }
  let filters = match dict {
    Some(value) => lookup_filters_text(value)
    None => "-"
  }
  {
    hit,
    kind: if raw_has_stream {
      "stream"
    } else {
      object_kind(object)
    },
    type_name,
    subtype_name,
    has_stream: raw_has_stream || object is PdfStreamObject(_),
    length,
    filters,
    note: "-",
  }
}

///|
fn object_summary_error(hit : PdfObjectHit, note : String) -> PdfObjectSummary {
  {
    hit,
    kind: "parse-error",
    type_name: "-",
    subtype_name: "-",
    has_stream: false,
    length: "-",
    filters: "-",
    note,
  }
}

///|
fn inspect_object(input : PdfInput, hit : PdfObjectHit) -> PdfObjectSummary {
  match object_view(input, hit) {
    Some(view) => {
      let parsed = @syntax.pdf_parse_indirect_object_from_view(view) catch {
        err =>
          return object_summary_error(
            hit,
            "parse: " + @core.pdf_error_summary(err),
          )
      }
      object_summary_from_parsed(
        hit,
        parsed.object,
        find_occurrence_from(view, 0, "stream") >= 0,
      )
    }
    None => object_summary_error(hit, "missing endobj")
  }
}

///|
fn summary_contains(
  summary : PdfObjectSummary,
  view : BytesView?,
  text : String,
) -> Bool {
  if text == "" {
    return true
  }
  if summary.kind.contains(text) ||
    summary.type_name.contains(text) ||
    summary.subtype_name.contains(text) ||
    summary.filters.contains(text) ||
    summary.note.contains(text) {
    return true
  }
  match view {
    Some(bytes) => count_occurrences(bytes, text) > 0
    None => false
  }
}

///|
fn object_summaries(
  input : PdfInput,
  limit : Int,
  contains : String?,
) -> Array[PdfObjectSummary] {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let out : Array[PdfObjectSummary] = []
  let needle = contains.unwrap_or("")
  for hit in scan.object_hits {
    if out.length() >= cap {
      break
    }
    let view = object_view(input, hit)
    let summary = inspect_object(input, hit)
    if summary_contains(summary, view, needle) {
      out.push(summary)
    }
  }
  out
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
fn object_summary_json(summary : PdfObjectSummary) -> Json {
  Json::object({
    "filters": Json::string(summary.filters),
    "generation": int_json(summary.hit.generation),
    "kind": Json::string(summary.kind),
    "length": Json::string(summary.length),
    "note": Json::string(summary.note),
    "object": int_json(summary.hit.number),
    "offset": int_json(summary.hit.offset),
    "stream": Json::boolean(summary.has_stream),
    "subtype": Json::string(summary.subtype_name),
    "type": Json::string(summary.type_name),
  })
}

///|
fn contains_json(contains : String?) -> Json {
  match contains {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn object_summaries_json(
  input : String,
  limit : Int,
  contains : String?,
  summaries : Array[PdfObjectSummary],
) -> String {
  Json::object({
    "contains": contains_json(contains),
    "limit": int_json(limit),
    "listed": int_json(summaries.length()),
    "objects": Json::array(
      [
        for summary in summaries => object_summary_json(summary)
      ],
    ),
    "path": Json::string(input),
  }).stringify() +
  "\n"
}

///|
fn object_summaries_markdown(
  input : String,
  limit : Int,
  contains : String?,
  summaries : Array[PdfObjectSummary],
) -> String {
  let mut out =
    $|# PDF Objects
    $|
    $|- path: `\{input}`
    $|- listed: \{summaries.length()}
    $|- limit: \{limit}
    $|
  match contains {
    Some(value) =>
      out += (
        $|- contains: `\{value}`
        $|
      )
    None => ()
  }
  out += (
    $|
    $|| object | generation | offset | kind | type | subtype | stream | length | filters | note |
    $||---:|---:|---:|---|---|---|---|---:|---|---|
    $|
  )
  for summary in summaries {
    out += (
      $|| \{summary.hit.number} | \{summary.hit.generation} | \{summary.hit.offset} | \{summary.kind} | \{summary.type_name} | \{summary.subtype_name} | \{bool_text(summary.has_stream)} | \{summary.length} | \{summary.filters} | \{summary.note} |
      $|
    )
  }
  out
}

///|
fn run_objects(
  input : String,
  limit : Int,
  contains : String?,
  as_json : Bool,
) -> Unit {
  let summaries = object_summaries(read_pdf_input(input), limit, contains)
  let out = if as_json {
    object_summaries_json(input, limit, contains, summaries)
  } else {
    object_summaries_markdown(input, limit, contains, summaries)
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
    Objects(input, limit, contains, as_json) =>
      run_objects(input, limit, contains, as_json)
  }
}
