///|
fn form_field_type_label(raw : String) -> String {
  match raw {
    "/Tx" => "text (/Tx)"
    "/Btn" => "button (/Btn)"
    "/Ch" => "choice (/Ch)"
    "/Sig" => "signature (/Sig)"
    "-" => "-"
    other => other
  }
}

///|
fn object_collection_text(object : @syntax.PdfObject) -> String {
  match object {
    PdfArray(items) => {
      let mut refs = 0
      for item in items {
        if item is PdfIndirect(_) {
          refs += 1
        }
      }
      if refs == items.length() {
        "\{items.length()} refs"
      } else {
        "\{items.length()} items"
      }
    }
    PdfIndirect(number) => "ref:\{number}"
    _ =>
      match object_text_value(object) {
        Some(value) => value
        None => object_kind(object)
      }
  }
}

///|
fn lookup_collection_text(dict : @syntax.PdfObject, key : String) -> String {
  match lookup_object(dict, key) {
    Some(value) => object_collection_text(value)
    None => "-"
  }
}

///|
fn fallback_text(first : String?, second : String?) -> String {
  match first {
    Some(value) => value
    None => second.unwrap_or("-")
  }
}

///|
fn form_field_note(dict : @syntax.PdfObject) -> String {
  let notes : Array[String] = []
  if lookup_object(dict, "/FT") is Some(_) {
    notes.push("field")
  }
  if lookup_name_text(dict, "/Subtype") == "/Widget" {
    notes.push("widget")
  }
  if lookup_object(dict, "/AA") is Some(_) {
    notes.push("additional-actions")
  }
  if lookup_object(dict, "/A") is Some(_) {
    notes.push("action")
  }
  if lookup_object(dict, "/JS") is Some(_) ||
    lookup_object(dict, "/JavaScript") is Some(_) {
    notes.push("javascript")
  }
  if lookup_object(dict, "/XFA") is Some(_) {
    notes.push("xfa")
  }
  join_strings(notes, ",")
}

///|
fn is_acroform_object(dict : @syntax.PdfObject) -> Bool {
  lookup_object(dict, "/Fields") is Some(_) ||
  lookup_object(dict, "/NeedAppearances") is Some(_) ||
  lookup_object(dict, "/XFA") is Some(_)
}

///|
fn is_form_field_object(dict : @syntax.PdfObject) -> Bool {
  lookup_object(dict, "/FT") is Some(_) ||
  lookup_name_text(dict, "/Subtype") == "/Widget"
}

///|
fn form_field_summary(
  object_number : Int,
  dict : @syntax.PdfObject,
) -> PdfFormFieldSummary {
  let raw_type = lookup_name_text(dict, "/FT")
  {
    object_number,
    field_type: form_field_type_label(raw_type),
    name: fallback_text(
      lookup_text_value(dict, "/T"),
      lookup_text_value(dict, "/TU"),
    ),
    value: fallback_text(
      lookup_text_value(dict, "/V"),
      lookup_text_value(dict, "/DV"),
    ),
    flags: lookup_text_value(dict, "/Ff").unwrap_or("-"),
    kids: lookup_collection_text(dict, "/Kids"),
    note: form_field_note(dict),
  }
}

///|
fn form_summaries(input : PdfInput, limit : Int) -> PdfFormsSummary {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let fields : Array[PdfFormFieldSummary] = []
  let mut acroform_objects = 0
  let mut xfa_objects = 0
  let mut fields_found = 0
  for hit in scan.object_hits {
    match parse_object(input, hit) {
      Some(object) =>
        match object_dictionary(object) {
          Some(dict) => {
            if is_acroform_object(dict) {
              acroform_objects += 1
            }
            if lookup_object(dict, "/XFA") is Some(_) {
              xfa_objects += 1
            }
            if is_form_field_object(dict) {
              fields_found += 1
              if fields.length() < cap {
                fields.push(form_field_summary(hit.number, dict))
              }
            }
          }
          None => ()
        }
      None => ()
    }
  }
  { path: input.path, acroform_objects, xfa_objects, fields_found, fields }
}

///|
fn form_field_json(field : PdfFormFieldSummary) -> Json {
  Json::object({
    "field_type": Json::string(field.field_type),
    "flags": Json::string(field.flags),
    "kids": Json::string(field.kids),
    "name": Json::string(field.name),
    "note": Json::string(field.note),
    "object": int_json(field.object_number),
    "value": Json::string(field.value),
  })
}

///|
fn forms_json(summary : PdfFormsSummary, limit : Int) -> String {
  Json::object({
    "acroform_objects": int_json(summary.acroform_objects),
    "fields": Json::array(
      [
        for field in summary.fields => form_field_json(field)
      ],
    ),
    "fields_found": int_json(summary.fields_found),
    "limit": int_json(limit),
    "listed": int_json(summary.fields.length()),
    "path": Json::string(summary.path),
    "xfa_objects": int_json(summary.xfa_objects),
  }).stringify() +
  "\n"
}

///|
fn markdown_cell(text : String) -> String {
  text.replace(old="|", new="\\|").replace(old="\n", new=" ")
}

///|
fn forms_markdown(summary : PdfFormsSummary, limit : Int) -> String {
  let mut out =
    $|# PDF Forms
    $|
    $|- path: `\{summary.path}`
    $|- acroform objects: \{summary.acroform_objects}
    $|- xfa objects: \{summary.xfa_objects}
    $|- fields found: \{summary.fields_found}
    $|- listed: \{summary.fields.length()}
    $|- limit: \{limit}
    $|
    $|| object | field type | name | value | flags | kids | note |
    $||---:|---|---|---|---:|---|---|
    $|
  for field in summary.fields {
    out += (
      $|| \{field.object_number} | \{markdown_cell(field.field_type)} | \{markdown_cell(field.name)} | \{markdown_cell(field.value)} | \{markdown_cell(field.flags)} | \{markdown_cell(field.kids)} | \{markdown_cell(field.note)} |
      $|
    )
  }
  out
}

///|
fn run_forms(input : String, limit : Int, as_json : Bool) -> Unit {
  let summary = form_summaries(read_pdf_input(input), limit)
  let out = if as_json {
    forms_json(summary, limit)
  } else {
    forms_markdown(summary, limit)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
