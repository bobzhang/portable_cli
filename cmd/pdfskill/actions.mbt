///|
fn push_action_key(
  dict : @syntax.PdfObject,
  key : String,
  keys : Array[String],
) -> Unit {
  if lookup_object(dict, key) is Some(_) {
    keys.push(key)
  }
}

///|
fn action_trigger_text(dict : @syntax.PdfObject) -> String {
  let keys : Array[String] = []
  push_action_key(dict, "/OpenAction", keys)
  push_action_key(dict, "/AA", keys)
  push_action_key(dict, "/A", keys)
  push_action_key(dict, "/S", keys)
  push_action_key(dict, "/JS", keys)
  push_action_key(dict, "/JavaScript", keys)
  push_action_key(dict, "/URI", keys)
  push_action_key(dict, "/Launch", keys)
  push_action_key(dict, "/SubmitForm", keys)
  push_action_key(dict, "/ImportData", keys)
  join_strings(keys, ",")
}

///|
fn nested_action_dict(
  dict : @syntax.PdfObject,
  key : String,
) -> @syntax.PdfObject? {
  match lookup_object(dict, key) {
    Some(value) => object_dictionary(value)
    None => None
  }
}

///|
fn best_action_dict(dict : @syntax.PdfObject) -> @syntax.PdfObject {
  match nested_action_dict(dict, "/A") {
    Some(value) => value
    None => dict
  }
}

///|
fn action_type_text(dict : @syntax.PdfObject) -> String {
  let action = best_action_dict(dict)
  let action_type = lookup_name_text(action, "/S")
  if action_type != "-" {
    action_type
  } else if lookup_object(dict, "/OpenAction") is Some(_) {
    "open-action"
  } else if lookup_object(dict, "/AA") is Some(_) {
    "additional-actions"
  } else if lookup_object(action, "/JS") is Some(_) ||
    lookup_object(action, "/JavaScript") is Some(_) {
    "/JavaScript"
  } else if lookup_object(action, "/URI") is Some(_) {
    "/URI"
  } else {
    "-"
  }
}

///|
fn first_action_target(
  dict : @syntax.PdfObject,
  keys : Array[String],
) -> String? {
  for key in keys {
    match lookup_object(dict, key) {
      Some(value) => return Some(page_array_values_text(value, 6))
      None => ()
    }
  }
  None
}

///|
fn action_target_text(dict : @syntax.PdfObject) -> String {
  let action = best_action_dict(dict)
  match
    first_action_target(action, ["/URI", "/JS", "/JavaScript", "/F", "/D"]) {
    Some(value) => value
    None =>
      first_action_target(dict, ["/OpenAction", "/AA", "/A"]).unwrap_or("-")
  }
}

///|
fn action_risk(trigger : String, action_type : String) -> String {
  if action_type == "/JavaScript" ||
    action_type == "/Launch" ||
    action_type == "/SubmitForm" ||
    action_type == "/ImportData" ||
    trigger.contains("/JS") ||
    trigger.contains("/JavaScript") {
    "high"
  } else if trigger.contains("/OpenAction") || trigger.contains("/AA") {
    "medium"
  } else if action_type == "/URI" {
    "info"
  } else {
    "review"
  }
}

///|
fn action_note(dict : @syntax.PdfObject, action_type : String) -> String {
  let notes : Array[String] = []
  if lookup_object(dict, "/OpenAction") is Some(_) {
    notes.push("open-action")
  }
  if lookup_object(dict, "/AA") is Some(_) {
    notes.push("additional-actions")
  }
  if lookup_object(dict, "/A") is Some(_) {
    notes.push("annotation-action")
  }
  if lookup_object(dict, "/S") is Some(_) {
    notes.push("direct-action")
  }
  if action_type == "/JavaScript" {
    notes.push("javascript")
  }
  if action_type == "/URI" {
    notes.push("uri")
  }
  join_strings(notes, ",")
}

///|
fn is_action_candidate(dict : @syntax.PdfObject) -> Bool {
  action_trigger_text(dict) != "-"
}

///|
fn action_summary(
  object_number : Int,
  dict : @syntax.PdfObject,
) -> PdfActionSummary {
  let trigger = action_trigger_text(dict)
  let action_type = action_type_text(dict)
  {
    object_number,
    trigger,
    action_type,
    target: action_target_text(dict),
    risk: action_risk(trigger, action_type),
    note: action_note(dict, action_type),
  }
}

///|
fn action_summaries(input : PdfInput, limit : Int) -> PdfActionsSummary {
  let cap = if limit < 0 { 0 } else { limit }
  let scan = scan_pdf(input)
  let actions : Array[PdfActionSummary] = []
  let mut actions_found = 0
  for hit in scan.object_hits {
    match parse_object(input, hit) {
      Some(object) =>
        match object_dictionary(object) {
          Some(dict) if is_action_candidate(dict) => {
            actions_found += 1
            if actions.length() < cap {
              actions.push(action_summary(hit.number, dict))
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  { path: input.path, actions_found, actions }
}

///|
fn action_summary_json(action : PdfActionSummary) -> Json {
  Json::object({
    "action_type": Json::string(action.action_type),
    "note": Json::string(action.note),
    "object": int_json(action.object_number),
    "risk": Json::string(action.risk),
    "target": Json::string(action.target),
    "trigger": Json::string(action.trigger),
  })
}

///|
fn actions_json(summary : PdfActionsSummary, limit : Int) -> String {
  Json::object({
    "actions": Json::array(
      [
        for action in summary.actions => action_summary_json(action)
      ],
    ),
    "actions_found": int_json(summary.actions_found),
    "limit": int_json(limit),
    "listed": int_json(summary.actions.length()),
    "path": Json::string(summary.path),
  }).stringify() +
  "\n"
}

///|
fn actions_markdown(summary : PdfActionsSummary, limit : Int) -> String {
  let mut out =
    $|# PDF Actions
    $|
    $|- path: `\{summary.path}`
    $|- actions found: \{summary.actions_found}
    $|- listed: \{summary.actions.length()}
    $|- limit: \{limit}
    $|
    $|| object | risk | trigger | action type | target | note |
    $||---:|---|---|---|---|---|
    $|
  for action in summary.actions {
    out += (
      $|| \{action.object_number} | \{markdown_cell(action.risk)} | \{markdown_cell(action.trigger)} | \{markdown_cell(action.action_type)} | \{markdown_cell(action.target)} | \{markdown_cell(action.note)} |
      $|
    )
  }
  out
}

///|
fn run_actions(input : String, limit : Int, as_json : Bool) -> Unit {
  let summary = action_summaries(read_pdf_input(input), limit)
  let out = if as_json {
    actions_json(summary, limit)
  } else {
    actions_markdown(summary, limit)
  }
  @miniio.stdout.write_text(out) catch {
    err => die("pdfskill: failed to write stdout: \{err}", 1)
  }
}
