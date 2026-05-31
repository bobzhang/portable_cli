///|
fn summary_by_number(input : PdfInput, number : Int) -> PdfObjectSummary? {
  let scan = scan_pdf(input)
  for hit in scan.object_hits {
    if hit.number == number {
      return Some(inspect_object(input, hit))
    }
  }
  None
}

///|
fn indirect_number(object : @syntax.PdfObject) -> Int? {
  match object {
    PdfIndirect(number) => Some(number)
    _ => None
  }
}

///|
fn filespec_embedded_object(filespec : @syntax.PdfObject) -> Int? {
  match object_dictionary(filespec) {
    Some(dict) =>
      match lookup_object(dict, "/EF") {
        Some(ef) =>
          match object_dictionary(ef) {
            Some(ef_dict) => {
              match lookup_object(ef_dict, "/UF") {
                Some(value) =>
                  match indirect_number(value) {
                    Some(number) => return Some(number)
                    None => ()
                  }
                None => ()
              }
              match lookup_object(ef_dict, "/F") {
                Some(value) => indirect_number(value)
                None => None
              }
            }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn filespec_name(filespec : @syntax.PdfObject, embedded_object : Int) -> String {
  match object_dictionary(filespec) {
    Some(dict) => {
      match lookup_text_value(dict, "/UF") {
        Some(name) => return name
        None => ()
      }
      match lookup_text_value(dict, "/F") {
        Some(name) => name
        None => "attachment-\{embedded_object}.bin"
      }
    }
    None => "attachment-\{embedded_object}.bin"
  }
}

///|
fn safe_filename_char(value : Int) -> Bool {
  (value >= b'a'.to_int() && value <= b'z'.to_int()) ||
  (value >= b'A'.to_int() && value <= b'Z'.to_int()) ||
  (value >= b'0'.to_int() && value <= b'9'.to_int()) ||
  value == b'.'.to_int() ||
  value == b'-'.to_int() ||
  value == b'_'.to_int()
}

///|
fn safe_attachment_name(name : String, fallback_object : Int) -> String {
  let bytes = @utf8.encode(name)
  let output : Array[Byte] = []
  for index in 0..<bytes.length() {
    let value = bytes[index].to_int()
    if safe_filename_char(value) {
      output.push(bytes[index])
    } else {
      output.push(b'_')
    }
  }
  let cleaned = @utf8.decode_lossy(Bytes::from_array(output)).trim().to_owned()
  if cleaned == "" || cleaned == "." || cleaned == ".." {
    "attachment-\{fallback_object}.bin"
  } else if cleaned[0].to_int() == b'.'.to_int() {
    "attachment-\{fallback_object}-\{cleaned}"
  } else {
    cleaned
  }
}

///|
fn join_path(dir : String, name : String) -> String {
  if dir.has_suffix("/") {
    dir + name
  } else {
    dir + "/" + name
  }
}

///|
fn ensure_dir(path : String) -> Unit {
  let exists = @miniio.exists(path) catch {
    err => die("pdfskill: failed to inspect \{path}: \{err}", 1)
  }
  if exists {
    let is_dir = @miniio.is_dir(path) catch {
      err => die("pdfskill: failed to inspect \{path}: \{err}", 1)
    }
    if !is_dir {
      die("pdfskill: --extract-dir is not a directory: \{path}", 1)
    }
  } else {
    @miniio.mkdir(path) catch {
      err => die("pdfskill: failed to create \{path}: \{err}", 1)
    }
  }
}

///|
fn write_attachment(path : String, data : Bytes) -> Unit {
  @miniio.write_file(path, data) catch {
    err => die("pdfskill: failed to write \{path}: \{err}", 1)
  }
}

///|
fn attachment_from_filespec(
  input : PdfInput,
  filespec_hit : PdfObjectHit,
  filespec : @syntax.PdfObject,
  extract_dir : String?,
) -> PdfAttachmentSummary? {
  let embedded_object = match filespec_embedded_object(filespec) {
    Some(number) => number
    None => return None
  }
  let name = filespec_name(filespec, embedded_object)
  let stream_summary = match summary_by_number(input, embedded_object) {
    Some(summary) => summary
    None =>
      return Some({
        name,
        filespec_object: filespec_hit.number,
        embedded_object,
        raw_bytes: 0,
        decoded_bytes: "-",
        filters: "-",
        extracted_path: "-",
        note: "missing embedded stream",
      })
  }
  match stream_raw_view(input, stream_summary) {
    Some((raw, _, _)) => {
      let filters = split_filter_text(stream_summary.filters)
      let (decoded, status) = decode_stream(raw, filters)
      match decoded {
        Some(bytes) => {
          let (extracted_path, note) = match extract_dir {
            Some(dir) => {
              ensure_dir(dir)
              let path = join_path(
                dir,
                safe_attachment_name(name, embedded_object),
              )
              write_attachment(path, bytes)
              (path, "extracted")
            }
            None => ("-", "not-extracted")
          }
          Some({
            name,
            filespec_object: filespec_hit.number,
            embedded_object,
            raw_bytes: raw.length(),
            decoded_bytes: bytes.length().to_string(),
            filters: stream_summary.filters,
            extracted_path,
            note,
          })
        }
        None =>
          Some({
            name,
            filespec_object: filespec_hit.number,
            embedded_object,
            raw_bytes: raw.length(),
            decoded_bytes: "-",
            filters: stream_summary.filters,
            extracted_path: "-",
            note: status,
          })
      }
    }
    None =>
      Some({
        name,
        filespec_object: filespec_hit.number,
        embedded_object,
        raw_bytes: 0,
        decoded_bytes: "-",
        filters: stream_summary.filters,
        extracted_path: "-",
        note: "missing stream bytes",
      })
  }
}

///|
fn is_filespec_object(object : @syntax.PdfObject) -> Bool {
  match object_dictionary(object) {
    Some(dict) =>
      lookup_name_text(dict, "/Type") == "/Filespec" ||
      lookup_object(dict, "/EF") is Some(_)
    None => false
  }
}

///|
fn attachment_summaries(
  input : PdfInput,
  limit : Int,
  extract_dir : String?,
) -> Array[PdfAttachmentSummary] {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let output : Array[PdfAttachmentSummary] = []
  for hit in scan.object_hits {
    if output.length() >= cap {
      break
    }
    match parse_object(input, hit) {
      Some(object) if is_filespec_object(object) =>
        match attachment_from_filespec(input, hit, object, extract_dir) {
          Some(summary) => output.push(summary)
          None => ()
        }
      _ => ()
    }
  }
  output
}

///|
fn attachment_summary_json(summary : PdfAttachmentSummary) -> Json {
  Json::object({
    "decoded_bytes": Json::string(summary.decoded_bytes),
    "embedded_object": int_json(summary.embedded_object),
    "extracted_path": Json::string(summary.extracted_path),
    "filespec_object": int_json(summary.filespec_object),
    "filters": Json::string(summary.filters),
    "name": Json::string(summary.name),
    "note": Json::string(summary.note),
    "raw_bytes": int_json(summary.raw_bytes),
  })
}

///|
fn attachments_json(
  input : String,
  limit : Int,
  extract_dir : String?,
  summaries : Array[PdfAttachmentSummary],
) -> String {
  Json::object({
    "attachments": Json::array(
      [
        for summary in summaries => attachment_summary_json(summary)
      ],
    ),
    "extract_dir": match extract_dir {
      Some(dir) => Json::string(dir)
      None => Json::null()
    },
    "limit": int_json(limit),
    "listed": int_json(summaries.length()),
    "path": Json::string(input),
  }).stringify() +
  "\n"
}

///|
fn attachments_markdown(
  input : String,
  limit : Int,
  extract_dir : String?,
  summaries : Array[PdfAttachmentSummary],
) -> String {
  let mut out =
    $|# PDF Attachments
    $|
    $|- path: `\{input}`
    $|- listed: \{summaries.length()}
    $|- limit: \{limit}
    $|
  match extract_dir {
    Some(dir) =>
      out += (
        $|- extract dir: `\{dir}`
        $|
      )
    None => ()
  }
  out += (
    $|
    $|| name | filespec object | embedded object | raw bytes | decoded bytes | filters | extracted path | note |
    $||---|---:|---:|---:|---:|---|---|---|
    $|
  )
  for summary in summaries {
    out += (
      $|| \{summary.name} | \{summary.filespec_object} | \{summary.embedded_object} | \{summary.raw_bytes} | \{summary.decoded_bytes} | \{summary.filters} | \{summary.extracted_path} | \{summary.note} |
      $|
    )
  }
  out
}

///|
fn run_attachments(
  input : String,
  limit : Int,
  extract_dir : String?,
  as_json : Bool,
) -> Unit {
  let summaries = attachment_summaries(
    read_pdf_input(input),
    limit,
    extract_dir,
  )
  let out = if as_json {
    attachments_json(input, limit, extract_dir, summaries)
  } else {
    attachments_markdown(input, limit, extract_dir, summaries)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
