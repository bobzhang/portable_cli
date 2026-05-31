///|
fn lookup_pdf_object_text(dict : @syntax.PdfObject, key : String) -> String {
  match lookup_object(dict, key) {
    Some(value) => page_array_values_text(value, 6)
    None => "-"
  }
}

///|
fn image_stream_summary(
  input : PdfInput,
  hit : PdfObjectHit,
  dict : @syntax.PdfObject,
  decode : Bool,
) -> PdfImageSummary {
  let object = inspect_object(input, hit)
  let (raw_bytes, decoded_bytes, note) = match stream_raw_view(input, object) {
    Some((raw, _, stream_status)) =>
      if decode {
        let filters = split_filter_text(object.filters)
        let (decoded, decode_status) = decode_stream(raw, filters)
        match decoded {
          Some(bytes) =>
            (
              raw.length(),
              bytes.length().to_string(),
              stream_status + "," + decode_status,
            )
          None => (raw.length(), "-", stream_status + "," + decode_status)
        }
      } else {
        (raw.length(), "-", stream_status)
      }
    None => (0, "-", "missing-stream-bytes")
  }
  {
    object_number: hit.number,
    width: lookup_pdf_object_text(dict, "/Width"),
    height: lookup_pdf_object_text(dict, "/Height"),
    color_space: lookup_pdf_object_text(dict, "/ColorSpace"),
    bits_per_component: lookup_pdf_object_text(dict, "/BitsPerComponent"),
    filters: object.filters,
    raw_bytes,
    decoded_bytes,
    note,
  }
}

///|
fn is_image_stream(dict : @syntax.PdfObject) -> Bool {
  lookup_name_text(dict, "/Subtype") == "/Image"
}

///|
fn image_summaries(
  input : PdfInput,
  limit : Int,
  decode : Bool,
) -> PdfImagesSummary {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let images : Array[PdfImageSummary] = []
  let mut images_found = 0
  for hit in scan.object_hits {
    match parse_object(input, hit) {
      Some(object) =>
        match object_dictionary(object) {
          Some(dict) if is_image_stream(dict) => {
            images_found += 1
            if images.length() < cap {
              images.push(image_stream_summary(input, hit, dict, decode))
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  { path: input.path, images_found, images }
}

///|
fn image_summary_json(image : PdfImageSummary) -> Json {
  Json::object({
    "bits_per_component": Json::string(image.bits_per_component),
    "color_space": Json::string(image.color_space),
    "decoded_bytes": Json::string(image.decoded_bytes),
    "filters": Json::string(image.filters),
    "height": Json::string(image.height),
    "note": Json::string(image.note),
    "object": int_json(image.object_number),
    "raw_bytes": int_json(image.raw_bytes),
    "width": Json::string(image.width),
  })
}

///|
fn images_json(
  summary : PdfImagesSummary,
  limit : Int,
  decode : Bool,
) -> String {
  Json::object({
    "decode": Json::boolean(decode),
    "images": Json::array(
      [
        for image in summary.images => image_summary_json(image)
      ],
    ),
    "images_found": int_json(summary.images_found),
    "limit": int_json(limit),
    "listed": int_json(summary.images.length()),
    "path": Json::string(summary.path),
  }).stringify() +
  "\n"
}

///|
fn images_markdown(
  summary : PdfImagesSummary,
  limit : Int,
  decode : Bool,
) -> String {
  let mut out =
    $|# PDF Images
    $|
    $|- path: `\{summary.path}`
    $|- images found: \{summary.images_found}
    $|- listed: \{summary.images.length()}
    $|- limit: \{limit}
    $|- decode: \{bool_text(decode)}
    $|
    $|| object | width | height | color space | bits | filters | raw bytes | decoded bytes | note |
    $||---:|---:|---:|---|---:|---|---:|---:|---|
    $|
  for image in summary.images {
    out += (
      $|| \{image.object_number} | \{markdown_cell(image.width)} | \{markdown_cell(image.height)} | \{markdown_cell(image.color_space)} | \{markdown_cell(image.bits_per_component)} | \{markdown_cell(image.filters)} | \{image.raw_bytes} | \{markdown_cell(image.decoded_bytes)} | \{markdown_cell(image.note)} |
      $|
    )
  }
  out
}

///|
fn run_images(
  input : String,
  limit : Int,
  decode : Bool,
  as_json : Bool,
) -> Unit {
  let summary = image_summaries(read_pdf_input(input), limit, decode)
  let out = if as_json {
    images_json(summary, limit, decode)
  } else {
    images_markdown(summary, limit, decode)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
