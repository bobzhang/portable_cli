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
    "jqlet",
    about="Format JSON and extract simple dotted paths.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "compact",
        short='c',
        long="compact",
        about="print compact JSON",
      ),
      @argparse.FlagArg(
        "raw",
        short='r',
        long="raw",
        about="print selected JSON strings without quotes",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input JSON file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "get",
        short='g',
        long="get",
        about="extract path, for example user.name or items[0].id",
      ),
      @argparse.OptionArg(
        "indent",
        short='i',
        long="indent",
        about="pretty-print indentation",
        default_values=["2"],
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write output to a guest-visible file",
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("jqlet: failed to read argv: \{err}", 2)
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
fn read_input(matches : @argparse.Matches) -> String {
  match option(matches, "file") {
    Some(path) =>
      @miniio.read_text_file(path) catch {
        err => die("jqlet: failed to read \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdin.read_all().text() catch {
        err => die("jqlet: failed to read stdin: \{err}", 1)
      }
  }
}

///|
fn normalize_path(path : String) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < path.length() {
    match path.get_char(i) {
      Some('[') => {
        if !out.is_empty() && !out.to_string().has_suffix(".") {
          out.write_char('.')
        }
        i += 1
      }
      Some(']') => i += 1
      Some(ch) => {
        out.write_char(ch)
        i += 1
      }
      None => i += 1
    }
  }
  out.to_string()
}

///|
fn select_segment(json : Json, segment : String) -> Json? {
  if segment.is_empty() {
    return Some(json)
  }
  try @string.parse_int(segment) catch {
    _ =>
      match json {
        Object(fields) => fields.get(segment)
        _ => None
      }
  } noraise {
    index =>
      match json {
        Array(items) => items.get(index)
        _ => None
      }
  }
}

///|
fn select_path(json : Json, path : String) -> Json? {
  let mut current = json
  for part in normalize_path(path).split(".") {
    match select_segment(current, part.to_owned()) {
      Some(next) => current = next
      None => return None
    }
  }
  Some(current)
}

///|
fn selected_json(json : Json, matches : @argparse.Matches) -> Json {
  match option(matches, "get") {
    Some(path) =>
      match select_path(json, path) {
        Some(found) => found
        None => die("jqlet: path not found: \{path}", 1)
      }
    None => json
  }
}

///|
fn render_json(json : Json, matches : @argparse.Matches) -> String {
  if flag(matches, "raw") {
    match json {
      String(text) => return text
      _ => ()
    }
  }
  if flag(matches, "compact") {
    json.stringify()
  } else {
    let indent = int_value(matches, "indent", 2).clamp(min=0, max=8)
    json.stringify(indent~)
  }
}

///|
fn write_output(text : String, matches : @argparse.Matches) -> Unit {
  let output = text + "\n"
  match option(matches, "output") {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("jqlet: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("jqlet: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let matches = parse()
  let json = @json.parse(read_input(matches)) catch {
    err => die("jqlet: invalid JSON: \{err}", 1)
  }
  write_output(render_json(selected_json(json, matches), matches), matches)
}
