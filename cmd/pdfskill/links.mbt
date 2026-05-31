///|
fn parse_pdf_string_at(data : BytesView, start : Int) -> (String, Int)? {
  if start >= data.length() {
    None
  } else if data[start] == b'(' {
    parse_literal_pdf_string(data, start)
  } else if data[start] == b'<' {
    parse_hex_pdf_string(data, start)
  } else {
    None
  }
}

///|
fn append_links_from_object(
  view : BytesView,
  object_number : Int,
  limit : Int,
  links : Array[PdfLinkSummary],
) -> Unit {
  let uri_token = "/URI"
  let mut index = 0
  while links.length() < limit {
    let found = find_occurrence_from(view, index, uri_token)
    if found < 0 {
      return
    }
    let value_start = skip_spaces(view, found + uri_token.length())
    match parse_pdf_string_at(view, value_start) {
      Some((target, _)) =>
        links.push(PdfLinkSummary::{ object_number, target, note: "uri-action" })
      None => ()
    }
    index = found + uri_token.length()
  }
}

///|
fn link_summaries(input : PdfInput, limit : Int) -> Array[PdfLinkSummary] {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let links : Array[PdfLinkSummary] = []
  for hit in scan.object_hits {
    if links.length() >= cap {
      break
    }
    match object_view(input, hit) {
      Some(view) => append_links_from_object(view, hit.number, cap, links)
      None => ()
    }
  }
  links
}

///|
fn link_json(link : PdfLinkSummary) -> Json {
  Json::object({
    "note": Json::string(link.note),
    "object": int_json(link.object_number),
    "target": Json::string(link.target),
  })
}

///|
fn links_json(
  input : String,
  limit : Int,
  links : Array[PdfLinkSummary],
) -> String {
  Json::object({
    "links": Json::array([ for link in links => link_json(link) ]),
    "limit": int_json(limit),
    "listed": int_json(links.length()),
    "path": Json::string(input),
  }).stringify() +
  "\n"
}

///|
fn links_markdown(
  input : String,
  limit : Int,
  links : Array[PdfLinkSummary],
) -> String {
  let out = StringBuilder()
  out.write_string("# PDF Links\n\n")
  out.write_string("- path: `\{input}`\n")
  out.write_string("- listed: \{links.length()}\n")
  out.write_string("- limit: \{limit}\n")
  out.write_string("\n| object | target | note |\n")
  out.write_string("|---:|---|---|\n")
  for link in links {
    out.write_string(
      "| \{link.object_number} | \{link.target} | \{link.note} |\n",
    )
  }
  out.to_string()
}

///|
fn run_links(input : String, limit : Int, as_json : Bool) -> Unit {
  let links = link_summaries(read_pdf_input(input), limit)
  let out = if as_json {
    links_json(input, limit, links)
  } else {
    links_markdown(input, limit, links)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
