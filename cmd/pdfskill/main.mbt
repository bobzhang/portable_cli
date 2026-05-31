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
struct PdfPageSummary {
  page_number : Int
  object_number : Int
  media_box : String
  rotate : String
  contents : String
  annots : String
  resources : String
  note : String
}

///|
struct PdfPagesSummary {
  path : String
  pages_found : Int
  pages : Array[PdfPageSummary]
}

///|
struct PdfStreamSummary {
  object : PdfObjectSummary
  raw_start : Int
  raw_bytes : Int
  decoded_bytes : String
  decode_status : String
  preview : String
}

///|
struct PdfMetadataSummary {
  path : String
  info_objects : Int
  title : String
  author : String
  subject : String
  keywords : String
  creator : String
  producer : String
  creation_date : String
  mod_date : String
  xmp_objects : Int
  xmp_preview : String
}

///|
struct PdfTextSummary {
  path : String
  streams_scanned : Int
  fragments : Int
  extracted_chars : Int
  text : String
}

///|
struct PdfAttachmentSummary {
  name : String
  filespec_object : Int
  embedded_object : Int
  raw_bytes : Int
  decoded_bytes : String
  filters : String
  extracted_path : String
  note : String
}

///|
struct PdfLinkSummary {
  object_number : Int
  target : String
  note : String
}

///|
struct PdfFormFieldSummary {
  object_number : Int
  field_type : String
  name : String
  value : String
  flags : String
  kids : String
  note : String
}

///|
struct PdfFormsSummary {
  path : String
  acroform_objects : Int
  xfa_objects : Int
  fields_found : Int
  fields : Array[PdfFormFieldSummary]
}

///|
enum PdfSkillCommand {
  Brief(String, Bool, String?)
  Doctor(String)
  Map(String, Int)
  Pages(String, Int, Bool)
  Objects(String, Int, String?, Bool)
  Streams(String, Int, Bool, Int, Bool)
  Metadata(String, Int, Bool)
  Text(String, Int, Bool)
  Attachments(String, Int, String?, Bool)
  Links(String, Int, Bool)
  Forms(String, Int, Bool)
  MakeText(String?, String, String, Array[String])
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
    about="Portable PDF inspection, extraction, and creation for agent skills.",
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
        "pages",
        about="List page dictionaries and their content/annotation references.",
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
            about="maximum pages to print",
            default_values=["80"],
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
      @argparse.Command(
        "streams",
        about="List PDF streams and optionally decode bounded previews.",
        flags=[
          @argparse.FlagArg(
            "json",
            long="json",
            about="write compact JSON instead of Markdown",
          ),
          @argparse.FlagArg(
            "decode",
            long="decode",
            about="decode supported filters before previewing stream bytes",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "limit",
            long="limit",
            about="maximum streams to print",
            default_values=["20"],
          ),
          @argparse.OptionArg(
            "max-bytes",
            long="max-bytes",
            about="maximum bytes to include in each preview",
            default_values=["96"],
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
        "metadata",
        about="Extract common Info dictionary fields and XMP metadata previews.",
        flags=[
          @argparse.FlagArg(
            "json",
            long="json",
            about="write compact JSON instead of Markdown",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "max-bytes",
            long="max-bytes",
            about="maximum XMP bytes to include in the preview",
            default_values=["160"],
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
        "text",
        about="Best-effort text extraction from decoded content streams.",
        flags=[
          @argparse.FlagArg(
            "json",
            long="json",
            about="write compact JSON instead of Markdown",
          ),
        ],
        options=[
          @argparse.OptionArg(
            "max-chars",
            long="max-chars",
            about="maximum extracted characters to print",
            default_values=["2000"],
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
        "attachments",
        about="List and optionally extract embedded file attachments.",
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
            about="maximum attachments to print",
            default_values=["40"],
          ),
          @argparse.OptionArg(
            "extract-dir",
            long="extract-dir",
            about="write decoded embedded files into this directory",
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
        "links",
        about="Extract URI action targets from PDF objects.",
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
            about="maximum links to print",
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
        "forms",
        about="Extract AcroForm/XFA field signals from PDF objects.",
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
            about="maximum fields to print",
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
        "make-text",
        about="Create a simple one-page text PDF.",
        options=[
          @argparse.OptionArg(
            "output",
            short='o',
            long="output",
            about="write PDF bytes to this file; stdout is used when omitted",
          ),
          @argparse.OptionArg(
            "title",
            long="title",
            about="PDF title metadata",
            default_values=["Portable PDF"],
          ),
          @argparse.OptionArg(
            "page-size",
            long="page-size",
            about="page size: letter or a4",
            default_values=["letter"],
          ),
        ],
        positionals=[
          @argparse.PositionArg(
            "text",
            about="text words; stdin is used when omitted",
            num_args=@argparse.ValueRange(lower=0),
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
    Some(("pages", sub)) =>
      Pages(
        required_value(sub, "input"),
        int_value(sub, "limit", 80),
        flag(sub, "json"),
      )
    Some(("objects", sub)) =>
      Objects(
        required_value(sub, "input"),
        int_value(sub, "limit", 40),
        option(sub, "contains"),
        flag(sub, "json"),
      )
    Some(("streams", sub)) =>
      Streams(
        required_value(sub, "input"),
        int_value(sub, "limit", 20),
        flag(sub, "decode"),
        int_value(sub, "max-bytes", 96),
        flag(sub, "json"),
      )
    Some(("metadata", sub)) =>
      Metadata(
        required_value(sub, "input"),
        int_value(sub, "max-bytes", 160),
        flag(sub, "json"),
      )
    Some(("text", sub)) =>
      Text(
        required_value(sub, "input"),
        int_value(sub, "max-chars", 2000),
        flag(sub, "json"),
      )
    Some(("attachments", sub)) =>
      Attachments(
        required_value(sub, "input"),
        int_value(sub, "limit", 40),
        option(sub, "extract-dir"),
        flag(sub, "json"),
      )
    Some(("links", sub)) =>
      Links(
        required_value(sub, "input"),
        int_value(sub, "limit", 40),
        flag(sub, "json"),
      )
    Some(("forms", sub)) =>
      Forms(
        required_value(sub, "input"),
        int_value(sub, "limit", 40),
        flag(sub, "json"),
      )
    Some(("make-text", sub)) =>
      MakeText(
        option(sub, "output"),
        value(sub, "title", "Portable PDF"),
        value(sub, "page-size", "letter"),
        values(sub, "text"),
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
fn split_filter_text(text : String) -> Array[String] {
  let filters : Array[String] = []
  if text == "-" || text == "" {
    return filters
  }
  let mut start = 0
  for index in 0..<text.length() {
    if text[index].to_int() == b','.to_int() {
      filters.push(text[start:index].to_owned())
      start = index + 1
    }
  }
  filters.push(text[start:].to_owned())
  filters
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
fn parse_object(input : PdfInput, hit : PdfObjectHit) -> @syntax.PdfObject? {
  match object_view(input, hit) {
    Some(view) => {
      let parsed = @syntax.pdf_parse_indirect_object_from_view(view) catch {
        _ => return None
      }
      Some(parsed.object)
    }
    None => None
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
fn skip_stream_newline(view : BytesView, start : Int) -> Int {
  if start < view.length() && view[start] == b'\r' {
    if start + 1 < view.length() && view[start + 1] == b'\n' {
      start + 2
    } else {
      start + 1
    }
  } else if start < view.length() && view[start] == b'\n' {
    start + 1
  } else {
    start
  }
}

///|
fn trim_stream_end_newline(view : BytesView, start : Int, end : Int) -> Int {
  let mut finish = end
  if finish > start && view[finish - 1] == b'\n' {
    finish -= 1
    if finish > start && view[finish - 1] == b'\r' {
      finish -= 1
    }
  } else if finish > start && view[finish - 1] == b'\r' {
    finish -= 1
  }
  finish
}

///|
fn stream_declared_length(summary : PdfObjectSummary) -> Int? {
  let value = @string.parse_int(summary.length) catch { _ => return None }
  Some(value)
}

///|
fn stream_raw_view(
  input : PdfInput,
  summary : PdfObjectSummary,
) -> (BytesView, Int, String)? {
  let object_view = match object_view(input, summary.hit) {
    Some(value) => value
    None => return None
  }
  let stream_token = find_occurrence_from(object_view, 0, "stream")
  if stream_token < 0 {
    return None
  }
  let endstream = find_occurrence_from(
    object_view,
    stream_token + 6,
    "endstream",
  )
  if endstream < 0 {
    return None
  }
  let data_start_rel = skip_stream_newline(object_view, stream_token + 6)
  let fallback_end_rel = trim_stream_end_newline(
    object_view, data_start_rel, endstream,
  )
  let (data_end_rel, status) = match stream_declared_length(summary) {
    Some(length) if length >= 0 &&
      data_start_rel + length <= object_view.length() =>
      (data_start_rel + length, "ok")
    Some(_) => (fallback_end_rel, "length-mismatch")
    None => (fallback_end_rel, "length-unresolved")
  }
  let length = if data_end_rel >= data_start_rel {
    data_end_rel - data_start_rel
  } else {
    0
  }
  let cursor = @core.byte_cursor_of_bytes(input.data)
  let absolute_start = summary.hit.offset + data_start_rel
  let raw = cursor.view_at(absolute_start, length) catch { _ => return None }
  Some((raw, absolute_start, status))
}

///|
fn decode_single_filter(filter : String, data : Bytes) -> Bytes? {
  if filter == "/FlateDecode" || filter == "/Fl" {
    Some(@flate.pdf_flate_decode(data) catch { _ => return None })
  } else if filter == "/ASCIIHexDecode" || filter == "/AHx" {
    Some(@codec.pdf_ascii_hex_decode(data) catch { _ => return None })
  } else if filter == "/ASCII85Decode" || filter == "/A85" {
    Some(@codec.pdf_ascii85_decode(data) catch { _ => return None })
  } else if filter == "/RunLengthDecode" || filter == "/RL" {
    Some(@codec.pdf_run_length_decode(data))
  } else if filter == "/LZWDecode" || filter == "/LZW" {
    Some(@codec.pdf_lzw_decode(data) catch { _ => return None })
  } else if filter == "/Crypt" {
    Some(data)
  } else {
    None
  }
}

///|
fn decode_stream(raw : BytesView, filters : Array[String]) -> (Bytes?, String) {
  if filters.length() == 0 {
    return (Some(raw.to_owned()), "identity")
  }
  let mut current = raw.to_owned()
  for filter in filters {
    match decode_single_filter(filter, current) {
      Some(decoded) => current = decoded
      None => return (None, "unsupported-or-failed:\{filter}")
    }
  }
  (Some(current), "ok")
}

///|
fn preview_bytes(data : BytesView, max_bytes : Int) -> String {
  let cap = if max_bytes < 0 {
    0
  } else if max_bytes < data.length() {
    max_bytes
  } else {
    data.length()
  }
  let output : Array[Byte] = []
  for index in 0..<cap {
    let value = data[index].to_int()
    if value >= 32 &&
      value <= 126 &&
      value != b'|'.to_int() &&
      value != b'`'.to_int() {
      output.push(data[index])
    } else {
      output.push(b'.')
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
fn stream_summary(
  input : PdfInput,
  object : PdfObjectSummary,
  decode : Bool,
  max_bytes : Int,
) -> PdfStreamSummary? {
  match stream_raw_view(input, object) {
    Some((raw, raw_start, status)) =>
      if decode {
        let filters = split_filter_text(object.filters)
        let (decoded, decode_status) = decode_stream(raw, filters)
        match decoded {
          Some(bytes) =>
            Some({
              object,
              raw_start,
              raw_bytes: raw.length(),
              decoded_bytes: bytes.length().to_string(),
              decode_status,
              preview: preview_bytes(bytes, max_bytes),
            })
          None =>
            Some({
              object,
              raw_start,
              raw_bytes: raw.length(),
              decoded_bytes: "-",
              decode_status,
              preview: preview_bytes(raw, max_bytes),
            })
        }
      } else {
        Some({
          object,
          raw_start,
          raw_bytes: raw.length(),
          decoded_bytes: "-",
          decode_status: status,
          preview: preview_bytes(raw, max_bytes),
        })
      }
    None => None
  }
}

///|
fn stream_summaries(
  input : PdfInput,
  limit : Int,
  decode : Bool,
  max_bytes : Int,
) -> Array[PdfStreamSummary] {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let out : Array[PdfStreamSummary] = []
  for hit in scan.object_hits {
    if out.length() >= cap {
      break
    }
    let object = inspect_object(input, hit)
    if object.has_stream {
      match stream_summary(input, object, decode, max_bytes) {
        Some(summary) => out.push(summary)
        None => ()
      }
    }
  }
  out
}

///|
fn pdf_string_text(bytes : Bytes) -> String {
  if bytes.length() >= 2 &&
    bytes[0].to_int() == 0xFE &&
    bytes[1].to_int() == 0xFF {
    let output : Array[Byte] = []
    let mut index = 2
    while index + 1 < bytes.length() {
      if bytes[index].to_int() == 0 {
        output.push(bytes[index + 1])
      } else {
        output.push(b'.')
      }
      index += 2
    }
    @utf8.decode_lossy(Bytes::from_array(output))
  } else {
    @utf8.decode_lossy(bytes)
  }
}

///|
fn object_text_value(object : @syntax.PdfObject) -> String? {
  match object {
    PdfString(bytes) => Some(pdf_string_text(bytes))
    PdfNameObject(name) => Some(pdf_name_text(name))
    PdfInteger(value) => Some(value.to_string())
    PdfIndirect(number) => Some("ref:\{number}")
    _ => None
  }
}

///|
fn lookup_text_value(dict : @syntax.PdfObject, key : String) -> String? {
  match lookup_object(dict, key) {
    Some(value) => object_text_value(value)
    None => None
  }
}

///|
fn first_metadata_value(current : String, next : String?) -> String {
  if current != "-" {
    current
  } else {
    next.unwrap_or("-")
  }
}

///|
fn has_info_metadata(dict : @syntax.PdfObject) -> Bool {
  lookup_object(dict, "/Title") is Some(_) ||
  lookup_object(dict, "/Author") is Some(_) ||
  lookup_object(dict, "/Subject") is Some(_) ||
  lookup_object(dict, "/Keywords") is Some(_) ||
  lookup_object(dict, "/Creator") is Some(_) ||
  lookup_object(dict, "/Producer") is Some(_) ||
  lookup_object(dict, "/CreationDate") is Some(_) ||
  lookup_object(dict, "/ModDate") is Some(_)
}

///|
fn is_xmp_metadata_object(
  summary : PdfObjectSummary,
  view : BytesView?,
) -> Bool {
  summary.type_name == "/Metadata" ||
  summary.subtype_name == "/XML" ||
  (match view {
    Some(bytes) => count_occurrences(bytes, "<x:xmpmeta") > 0
    None => false
  })
}

///|
fn metadata_summary(input : PdfInput, max_bytes : Int) -> PdfMetadataSummary {
  let scan = scan_pdf(input)
  let mut info_objects = 0
  let mut title = "-"
  let mut author = "-"
  let mut subject = "-"
  let mut keywords = "-"
  let mut creator = "-"
  let mut producer = "-"
  let mut creation_date = "-"
  let mut mod_date = "-"
  let mut xmp_objects = 0
  let mut xmp_preview = "-"
  for hit in scan.object_hits {
    let summary = inspect_object(input, hit)
    match parse_object(input, hit) {
      Some(object) =>
        match object_dictionary(object) {
          Some(dict) =>
            if has_info_metadata(dict) {
              info_objects += 1
              title = first_metadata_value(
                title,
                lookup_text_value(dict, "/Title"),
              )
              author = first_metadata_value(
                author,
                lookup_text_value(dict, "/Author"),
              )
              subject = first_metadata_value(
                subject,
                lookup_text_value(dict, "/Subject"),
              )
              keywords = first_metadata_value(
                keywords,
                lookup_text_value(dict, "/Keywords"),
              )
              creator = first_metadata_value(
                creator,
                lookup_text_value(dict, "/Creator"),
              )
              producer = first_metadata_value(
                producer,
                lookup_text_value(dict, "/Producer"),
              )
              creation_date = first_metadata_value(
                creation_date,
                lookup_text_value(dict, "/CreationDate"),
              )
              mod_date = first_metadata_value(
                mod_date,
                lookup_text_value(dict, "/ModDate"),
              )
            }
          None => ()
        }
      None => ()
    }
    let view = object_view(input, hit)
    if summary.has_stream && is_xmp_metadata_object(summary, view) {
      xmp_objects += 1
      if xmp_preview == "-" {
        match stream_summary(input, summary, true, max_bytes) {
          Some(stream) => xmp_preview = stream.preview
          None => ()
        }
      }
    }
  }
  {
    path: input.path,
    info_objects,
    title,
    author,
    subject,
    keywords,
    creator,
    producer,
    creation_date,
    mod_date,
    xmp_objects,
    xmp_preview,
  }
}

///|
fn is_octal_digit(value : Int) -> Bool {
  value >= b'0'.to_int() && value <= b'7'.to_int()
}

///|
fn parse_literal_pdf_string(data : BytesView, start : Int) -> (String, Int)? {
  if start >= data.length() || data[start] != b'(' {
    return None
  }
  let output : Array[Byte] = []
  let mut index = start + 1
  let mut depth = 1
  while index < data.length() {
    let byte = data[index]
    if byte == b'\\' {
      if index + 1 >= data.length() {
        return None
      }
      let next = data[index + 1]
      match next {
        b'n' => output.push(b'\n')
        b'r' => output.push(b'\r')
        b't' => output.push(b'\t')
        b'b' | b'f' => output.push(b' ')
        b'(' | b')' | b'\\' => output.push(next)
        b'\r' =>
          if index + 2 < data.length() && data[index + 2] == b'\n' {
            index += 1
          }
        b'\n' => ()
        _ =>
          if is_octal_digit(next.to_int()) {
            let mut value = next.to_int() - b'0'.to_int()
            let mut consumed = 1
            while consumed < 3 &&
                  index + 1 + consumed < data.length() &&
                  is_octal_digit(data[index + 1 + consumed].to_int()) {
              value = value * 8 +
                data[index + 1 + consumed].to_int() -
                b'0'.to_int()
              consumed += 1
            }
            output.push((value & 0xFF).to_byte())
            index += consumed - 1
          } else {
            output.push(next)
          }
      }
      index += 2
    } else if byte == b'(' {
      depth += 1
      output.push(byte)
      index += 1
    } else if byte == b')' {
      depth -= 1
      if depth == 0 {
        return Some((pdf_string_text(Bytes::from_array(output)), index + 1))
      }
      output.push(byte)
      index += 1
    } else {
      output.push(byte)
      index += 1
    }
  }
  None
}

///|
fn parse_hex_pdf_string(data : BytesView, start : Int) -> (String, Int)? {
  if start >= data.length() || data[start] != b'<' {
    return None
  }
  if start + 1 < data.length() && data[start + 1] == b'<' {
    return None
  }
  let output : Array[Byte] = []
  let mut index = start + 1
  let mut high : Int? = None
  while index < data.length() {
    if data[index] == b'>' {
      match high {
        Some(value) => output.push((value << 4).to_byte())
        None => ()
      }
      return Some((pdf_string_text(Bytes::from_array(output)), index + 1))
    }
    if !@core.pdf_is_whitespace_byte(data[index].to_int()) {
      match @syntax.pdf_hex_value(data[index].to_int()) {
        Some(value) =>
          match high {
            Some(first) => {
              output.push(((first << 4) | value).to_byte())
              high = None
            }
            None => high = Some(value)
          }
        None => return None
      }
    }
    index += 1
  }
  None
}

///|
fn clean_text_fragment(text : String) -> String {
  let bytes = @utf8.encode(text)
  let output : Array[Byte] = []
  for index in 0..<bytes.length() {
    let value = bytes[index].to_int()
    if value == b'\n'.to_int() ||
      value == b'\r'.to_int() ||
      value == b'\t'.to_int() {
      output.push(b' ')
    } else if value >= 32 && value <= 126 {
      output.push(bytes[index])
    } else {
      output.push(b'.')
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output)).trim().to_owned()
}

///|
fn append_text_fragment(current : String, fragment : String) -> String {
  if fragment == "" {
    current
  } else if current == "" {
    fragment
  } else {
    current + "\n" + fragment
  }
}

///|
fn stream_text_fragments(data : BytesView, remaining : Int) -> (String, Int) {
  let mut text = ""
  let mut fragments = 0
  let mut index = 0
  while index < data.length() && text.length() < remaining {
    let parsed = if data[index] == b'(' {
      parse_literal_pdf_string(data, index)
    } else if data[index] == b'<' {
      parse_hex_pdf_string(data, index)
    } else {
      None
    }
    match parsed {
      Some((fragment, next)) => {
        let cleaned = clean_text_fragment(fragment)
        if cleaned != "" {
          text = append_text_fragment(text, cleaned)
          fragments += 1
        }
        index = next
      }
      None => index += 1
    }
  }
  if text.length() > remaining {
    (text[:remaining].to_owned(), fragments)
  } else {
    (text, fragments)
  }
}

///|
fn text_candidate_stream(summary : PdfObjectSummary) -> Bool {
  summary.has_stream &&
  summary.type_name != "/Metadata" &&
  summary.subtype_name != "/XML" &&
  summary.subtype_name != "/Image" &&
  summary.subtype_name != "/CIDFontType0C" &&
  summary.subtype_name != "/Type1C" &&
  summary.subtype_name != "/OpenType"
}

///|
fn text_summary(input : PdfInput, max_chars : Int) -> PdfTextSummary {
  let cap = if max_chars < 0 { 0 } else { max_chars }
  let scan = scan_pdf(input)
  let mut streams_scanned = 0
  let mut fragments = 0
  let mut text = ""
  for hit in scan.object_hits {
    if text.length() >= cap {
      break
    }
    let object = inspect_object(input, hit)
    if text_candidate_stream(object) {
      match stream_raw_view(input, object) {
        Some((raw, _, _)) => {
          let filters = split_filter_text(object.filters)
          let (decoded, _) = decode_stream(raw, filters)
          match decoded {
            Some(bytes) => {
              streams_scanned += 1
              let remaining = cap - text.length()
              let (chunk, count) = stream_text_fragments(bytes, remaining)
              if chunk != "" {
                text = append_text_fragment(text, chunk)
                fragments += count
              }
            }
            None => ()
          }
        }
        None => ()
      }
    }
  }
  {
    path: input.path,
    streams_scanned,
    fragments,
    extracted_chars: text.length(),
    text,
  }
}

///|
fn make_text_input(words : Array[String]) -> String {
  if words.is_empty() {
    let input = @miniio.stdin.read_all().text() catch {
        err => die("pdfskill: failed to read stdin: \{err}", 1)
      }
    let trimmed = input.trim().to_owned()
    if trimmed == "" {
      "Hello from portable pdfskill"
    } else {
      trimmed
    }
  } else {
    words.join(" ")
  }
}

///|
fn pdf_escape_literal(text : String) -> String {
  let bytes = @utf8.encode(text)
  let mut out = ""
  for index in 0..<bytes.length() {
    match bytes[index] {
      b'\\' => out += "\\\\"
      b'(' => out += "\\("
      b')' => out += "\\)"
      b'\r' | b'\n' | b'\t' => out += " "
      _ => out += @utf8.decode_lossy(Bytes::from_array([bytes[index]]))
    }
  }
  out
}

///|
fn make_text_page_size(name : String) -> (Int, Int) {
  let normalized = name.to_lower()
  if normalized == "letter" {
    (612, 792)
  } else if normalized == "a4" {
    (595, 842)
  } else {
    die("pdfskill: invalid --page-size: \{name} (expected letter or a4)", 2)
  }
}

///|
fn make_text_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      lines.push(" ")
    } else {
      lines.push(trimmed)
    }
  }
  if lines.is_empty() {
    lines.push("Hello from portable pdfskill")
  }
  lines
}

///|
fn make_text_content(text : String, page_height : Int) -> String {
  let mut out = "BT\n/F1 12 Tf\n72 \{page_height - 72} Td\n16 TL\n"
  let lines = make_text_lines(text)
  for index in 0..<lines.length() {
    if index > 0 {
      out += "T*\n"
    }
    out += "(\{pdf_escape_literal(lines[index])}) Tj\n"
  }
  out + "ET\n"
}

///|
fn pdf_xref_offset(offset : Int) -> String {
  offset.to_string().pad_start(10, '0') + " 00000 n \n"
}

///|
fn make_text_pdf(text : String, title : String, page_size : String) -> String {
  let (width, height) = make_text_page_size(page_size)
  let content = make_text_content(text, height)
  let mut pdf = "%PDF-1.4\n"
  let offsets : Array[Int] = []
  offsets.push(pdf.length())
  pdf += "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
  offsets.push(pdf.length())
  pdf += "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
  offsets.push(pdf.length())
  pdf += "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \{width} \{height}] /Resources << /Font << /F1 6 0 R >> >> /Contents 4 0 R >>\nendobj\n"
  offsets.push(pdf.length())
  pdf += "4 0 obj\n<< /Length \{content.length()} >>\nstream\n\{content}endstream\nendobj\n"
  offsets.push(pdf.length())
  pdf += "5 0 obj\n<< /Title (\{pdf_escape_literal(title)}) /Creator (pdfskill make-text) /Producer (portable_cli) >>\nendobj\n"
  offsets.push(pdf.length())
  pdf += "6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
  let xref = pdf.length()
  pdf += "xref\n0 7\n0000000000 65535 f \n"
  for offset in offsets {
    pdf += pdf_xref_offset(offset)
  }
  pdf += "trailer\n<< /Root 1 0 R /Info 5 0 R /Size 7 >>\nstartxref\n\{xref}\n%%EOF\n"
  pdf
}

///|
fn write_pdf_output(path : String?, pdf : String) -> Unit {
  match path {
    Some(output) => {
      @miniio.write_text_file(output, pdf) catch {
        err => die("pdfskill: failed to write \{output}: \{err}", 1)
      }
      @miniio.stdout.write_text("pdfskill make-text: wrote \{output}\n") catch {
        err => die("pdfskill: failed to write stdout: \{err}", 1)
      }
    }
    None =>
      @miniio.stdout.write_text(pdf) catch {
        err => die("pdfskill: failed to write stdout: \{err}", 1)
      }
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
fn stream_summary_json(summary : PdfStreamSummary) -> Json {
  Json::object({
    "decoded_bytes": Json::string(summary.decoded_bytes),
    "decode_status": Json::string(summary.decode_status),
    "filters": Json::string(summary.object.filters),
    "generation": int_json(summary.object.hit.generation),
    "length": Json::string(summary.object.length),
    "object": int_json(summary.object.hit.number),
    "offset": int_json(summary.object.hit.offset),
    "preview": Json::string(summary.preview),
    "raw_bytes": int_json(summary.raw_bytes),
    "raw_start": int_json(summary.raw_start),
    "subtype": Json::string(summary.object.subtype_name),
    "type": Json::string(summary.object.type_name),
  })
}

///|
fn stream_summaries_json(
  input : String,
  limit : Int,
  decode : Bool,
  max_bytes : Int,
  summaries : Array[PdfStreamSummary],
) -> String {
  Json::object({
    "decode": Json::boolean(decode),
    "limit": int_json(limit),
    "listed": int_json(summaries.length()),
    "max_bytes": int_json(max_bytes),
    "path": Json::string(input),
    "streams": Json::array(
      [
        for summary in summaries => stream_summary_json(summary)
      ],
    ),
  }).stringify() +
  "\n"
}

///|
fn stream_summaries_markdown(
  input : String,
  limit : Int,
  decode : Bool,
  max_bytes : Int,
  summaries : Array[PdfStreamSummary],
) -> String {
  let mut out =
    $|# PDF Streams
    $|
    $|- path: `\{input}`
    $|- listed: \{summaries.length()}
    $|- limit: \{limit}
    $|- decode: \{bool_text(decode)}
    $|- max bytes: \{max_bytes}
    $|
    $|| object | generation | offset | raw start | raw bytes | length | filters | decoded bytes | status | preview |
    $||---:|---:|---:|---:|---:|---:|---|---:|---|---|
    $|
  for summary in summaries {
    out += (
      $|| \{summary.object.hit.number} | \{summary.object.hit.generation} | \{summary.object.hit.offset} | \{summary.raw_start} | \{summary.raw_bytes} | \{summary.object.length} | \{summary.object.filters} | \{summary.decoded_bytes} | \{summary.decode_status} | `\{summary.preview}` |
      $|
    )
  }
  out
}

///|
fn run_streams(
  input : String,
  limit : Int,
  decode : Bool,
  max_bytes : Int,
  as_json : Bool,
) -> Unit {
  let summaries = stream_summaries(
    read_pdf_input(input),
    limit,
    decode,
    max_bytes,
  )
  let out = if as_json {
    stream_summaries_json(input, limit, decode, max_bytes, summaries)
  } else {
    stream_summaries_markdown(input, limit, decode, max_bytes, summaries)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}

///|
fn metadata_json(summary : PdfMetadataSummary) -> String {
  Json::object({
    "author": Json::string(summary.author),
    "creation_date": Json::string(summary.creation_date),
    "creator": Json::string(summary.creator),
    "info_objects": int_json(summary.info_objects),
    "keywords": Json::string(summary.keywords),
    "mod_date": Json::string(summary.mod_date),
    "path": Json::string(summary.path),
    "producer": Json::string(summary.producer),
    "subject": Json::string(summary.subject),
    "title": Json::string(summary.title),
    "xmp_objects": int_json(summary.xmp_objects),
    "xmp_preview": Json::string(summary.xmp_preview),
  }).stringify() +
  "\n"
}

///|
fn metadata_markdown(summary : PdfMetadataSummary) -> String {
  (
    $|# PDF Metadata
    $|
    $|- path: `\{summary.path}`
    $|- info objects: \{summary.info_objects}
    $|- title: \{summary.title}
    $|- author: \{summary.author}
    $|- subject: \{summary.subject}
    $|- keywords: \{summary.keywords}
    $|- creator: \{summary.creator}
    $|- producer: \{summary.producer}
    $|- creation date: \{summary.creation_date}
    $|- mod date: \{summary.mod_date}
    $|- xmp objects: \{summary.xmp_objects}
    $|- xmp preview: `\{summary.xmp_preview}`
    $|
  )
}

///|
fn run_metadata(input : String, max_bytes : Int, as_json : Bool) -> Unit {
  let summary = metadata_summary(read_pdf_input(input), max_bytes)
  let out = if as_json {
    metadata_json(summary)
  } else {
    metadata_markdown(summary)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}

///|
fn text_json(summary : PdfTextSummary) -> String {
  Json::object({
    "extracted_chars": int_json(summary.extracted_chars),
    "fragments": int_json(summary.fragments),
    "path": Json::string(summary.path),
    "streams_scanned": int_json(summary.streams_scanned),
    "text": Json::string(summary.text),
  }).stringify() +
  "\n"
}

///|
fn text_markdown(summary : PdfTextSummary) -> String {
  let body = if summary.text == "" {
    "(no text extracted)"
  } else {
    summary.text
  }
  (
    $|# PDF Text
    $|
    $|- path: `\{summary.path}`
    $|- streams scanned: \{summary.streams_scanned}
    $|- fragments: \{summary.fragments}
    $|- extracted chars: \{summary.extracted_chars}
    $|- mode: best-effort literal and hex strings from decoded content streams
    $|
    $|## Text
    $|
    $|\{body}
    $|
  )
}

///|
fn run_text(input : String, max_chars : Int, as_json : Bool) -> Unit {
  let summary = text_summary(read_pdf_input(input), max_chars)
  let out = if as_json { text_json(summary) } else { text_markdown(summary) }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}

///|
fn run_make_text(
  output : String?,
  title : String,
  page_size : String,
  words : Array[String],
) -> Unit {
  let text = make_text_input(words)
  write_pdf_output(output, make_text_pdf(text, title, page_size))
}

///|
fn main {
  match parse() {
    Brief(input, as_json, output) => run_brief(input, as_json, output)
    Doctor(input) => run_doctor(input)
    Map(input, limit) => run_map(input, limit)
    Pages(input, limit, as_json) => run_pages(input, limit, as_json)
    Objects(input, limit, contains, as_json) =>
      run_objects(input, limit, contains, as_json)
    Streams(input, limit, decode, max_bytes, as_json) =>
      run_streams(input, limit, decode, max_bytes, as_json)
    Metadata(input, max_bytes, as_json) =>
      run_metadata(input, max_bytes, as_json)
    Text(input, max_chars, as_json) => run_text(input, max_chars, as_json)
    Attachments(input, limit, extract_dir, as_json) =>
      run_attachments(input, limit, extract_dir, as_json)
    Links(input, limit, as_json) => run_links(input, limit, as_json)
    Forms(input, limit, as_json) => run_forms(input, limit, as_json)
    MakeText(output, title, page_size, words) =>
      run_make_text(output, title, page_size, words)
  }
}
