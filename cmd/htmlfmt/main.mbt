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
    "htmlfmt",
    about="Format HTML with bobzhang/html_parser as a portable WASIp1 CLI.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "compact",
        short='c',
        long="compact",
        about="write compact HTML instead of pretty HTML",
      ),
      @argparse.FlagArg(
        "document",
        short='d',
        long="document",
        about="parse input as a full HTML document; default is fragment mode",
      ),
      @argparse.FlagArg(
        "sanitize",
        long="sanitize",
        about="apply html_parser's default sanitizer before formatting",
      ),
      @argparse.FlagArg(
        "strict",
        long="strict",
        about="fail on the first parse error",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "file",
        short='f',
        long="file",
        about="input file; stdin is used when omitted",
      ),
      @argparse.OptionArg(
        "output",
        short='o',
        long="output",
        about="write formatted HTML to a guest-visible file",
      ),
      @argparse.OptionArg(
        "indent",
        short='i',
        long="indent",
        about="pretty-print indentation",
        default_values=["2"],
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "html",
        about="HTML fragment words; stdin is used when omitted",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("htmlfmt: failed to read argv: \{err}", 2)
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
  @string.parse_int(value(matches, name, fallback.to_string())) catch {
    _ => fallback
  }
}

///|
fn read_input(matches : @argparse.Matches) -> String {
  let inline = values(matches, "html")
  match option(matches, "file") {
    Some(path) => {
      if !inline.is_empty() {
        die("htmlfmt: use either --file or inline HTML, not both", 2)
      }
      @miniio.read_text_file(path) catch {
        err => die("htmlfmt: failed to read \{path}: \{err}", 1)
      }
    }
    None =>
      if inline.is_empty() {
        @miniio.stdin.read_all().text() catch {
          err => die("htmlfmt: failed to read stdin: \{err}", 1)
        }
      } else {
        inline.join(" ")
      }
  }
}

///|
fn html_error_message(error : @html_parser.HtmlError) -> String {
  match error {
    StrictMode(parse_error) =>
      "strict parse error: \{parse_error.code}: \{parse_error.message}"
    InvalidSerialization(message) => message
    UnsafeHtml(message) => message
    SelectorError(message) => message
  }
}

///|
fn format_html(input : String, matches : @argparse.Matches) -> String {
  let pretty = !flag(matches, "compact")
  let indent = int_value(matches, "indent", 2).clamp(min=0, max=8)
  let sanitize = flag(matches, "sanitize")
  let strict = flag(matches, "strict")
  try {
    let parsed = if flag(matches, "document") {
      @html_parser.parse(input, sanitize~, strict~)
    } else {
      @html_parser.parse_fragment(input, sanitize~, strict~)
    }
    parsed.to_html(pretty~, indent_size=indent)
  } catch {
    err => die("htmlfmt: \{html_error_message(err)}", 1)
  }
}

///|
fn write_output(text : String, matches : @argparse.Matches) -> Unit {
  let output = text + "\n"
  match option(matches, "output") {
    Some(path) =>
      @miniio.write_text_file(path, output) catch {
        err => die("htmlfmt: failed to write \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdout.write_text(output) catch {
        err => die("htmlfmt: failed to write stdout: \{err}", 1)
      }
  }
}

///|
fn main {
  let matches = parse()
  write_output(
    format_html(read_input(matches).trim().to_owned(), matches),
    matches,
  )
}
