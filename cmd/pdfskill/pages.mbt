///|
fn page_value_text(object : @syntax.PdfObject) -> String {
  match object {
    PdfNull => "null"
    PdfBoolean(value) => if value { "true" } else { "false" }
    PdfInteger(value) => value.to_string()
    PdfReal(value) => value.to_string()
    PdfString(bytes) => pdf_string_text(bytes)
    PdfNameObject(name) => pdf_name_text(name)
    PdfIndirect(number) => "ref:\{number}"
    PdfArray(items) => "\{items.length()} items"
    PdfDictionary(_) => "dict"
    PdfStreamObject(_) => "stream"
  }
}

///|
fn page_array_values_text(object : @syntax.PdfObject, limit : Int) -> String {
  match object {
    PdfArray(items) => {
      let values : Array[String] = []
      let cap = if limit < items.length() { limit } else { items.length() }
      for index in 0..<cap {
        values.push(page_value_text(items[index]))
      }
      if cap < items.length() {
        values.push("...")
      }
      if values.length() == 0 {
        "[]"
      } else {
        join_strings(values, " ")
      }
    }
    _ => page_value_text(object)
  }
}

///|
fn lookup_page_box_text(dict : @syntax.PdfObject, key : String) -> String {
  match lookup_object(dict, key) {
    Some(value) => page_array_values_text(value, 8)
    None => "-"
  }
}

///|
fn lookup_page_reference_text(dict : @syntax.PdfObject, key : String) -> String {
  match lookup_object(dict, key) {
    Some(value) => object_collection_text(value)
    None => "-"
  }
}

///|
fn page_note(dict : @syntax.PdfObject) -> String {
  let notes : Array[String] = []
  if lookup_object(dict, "/Contents") is Some(_) {
    notes.push("content")
  }
  if lookup_object(dict, "/Annots") is Some(_) {
    notes.push("annots")
  }
  if lookup_object(dict, "/MediaBox") is None {
    notes.push("inherits-media-box")
  }
  if lookup_object(dict, "/Resources") is None {
    notes.push("inherits-resources")
  }
  if lookup_object(dict, "/AA") is Some(_) {
    notes.push("page-actions")
  }
  if lookup_object(dict, "/Thumb") is Some(_) {
    notes.push("thumbnail")
  }
  join_strings(notes, ",")
}

///|
fn is_page_object(dict : @syntax.PdfObject) -> Bool {
  lookup_name_text(dict, "/Type") == "/Page"
}

///|
fn page_summary(
  page_number : Int,
  object_number : Int,
  dict : @syntax.PdfObject,
) -> PdfPageSummary {
  {
    page_number,
    object_number,
    media_box: lookup_page_box_text(dict, "/MediaBox"),
    rotate: lookup_text_value(dict, "/Rotate").unwrap_or("0"),
    contents: lookup_page_reference_text(dict, "/Contents"),
    annots: lookup_page_reference_text(dict, "/Annots"),
    resources: lookup_page_reference_text(dict, "/Resources"),
    note: page_note(dict),
  }
}

///|
fn page_summaries(input : PdfInput, limit : Int) -> PdfPagesSummary {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let pages : Array[PdfPageSummary] = []
  let mut pages_found = 0
  for hit in scan.object_hits {
    match parse_object(input, hit) {
      Some(object) =>
        match object_dictionary(object) {
          Some(dict) if is_page_object(dict) => {
            pages_found += 1
            if pages.length() < cap {
              pages.push(page_summary(pages_found, hit.number, dict))
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  { path: input.path, pages_found, pages }
}

///|
fn page_summary_json(page : PdfPageSummary) -> Json {
  Json::object({
    "annots": Json::string(page.annots),
    "contents": Json::string(page.contents),
    "media_box": Json::string(page.media_box),
    "note": Json::string(page.note),
    "object": int_json(page.object_number),
    "page": int_json(page.page_number),
    "resources": Json::string(page.resources),
    "rotate": Json::string(page.rotate),
  })
}

///|
fn pages_json(summary : PdfPagesSummary, limit : Int) -> String {
  Json::object({
    "limit": int_json(limit),
    "listed": int_json(summary.pages.length()),
    "pages": Json::array(
      [
        for page in summary.pages => page_summary_json(page)
      ],
    ),
    "pages_found": int_json(summary.pages_found),
    "path": Json::string(summary.path),
  }).stringify() +
  "\n"
}

///|
fn pages_markdown(summary : PdfPagesSummary, limit : Int) -> String {
  let mut out =
    $|# PDF Pages
    $|
    $|- path: `\{summary.path}`
    $|- pages found: \{summary.pages_found}
    $|- listed: \{summary.pages.length()}
    $|- limit: \{limit}
    $|
    $|| page | object | media box | rotate | contents | annots | resources | note |
    $||---:|---:|---|---:|---|---|---|---|
    $|
  for page in summary.pages {
    out += (
      $|| \{page.page_number} | \{page.object_number} | \{markdown_cell(page.media_box)} | \{markdown_cell(page.rotate)} | \{markdown_cell(page.contents)} | \{markdown_cell(page.annots)} | \{markdown_cell(page.resources)} | \{markdown_cell(page.note)} |
      $|
    )
  }
  out
}

///|
fn run_pages(input : String, limit : Int, as_json : Bool) -> Unit {
  let summary = page_summaries(read_pdf_input(input), limit)
  let out = if as_json {
    pages_json(summary, limit)
  } else {
    pages_markdown(summary, limit)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
