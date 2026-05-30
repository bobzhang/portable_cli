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
    "cow",
    about="Wrap text in a speech bubble and render a small ASCII cow.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "think",
        short='t',
        long="think",
        about="use a thought bubble tail",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "width",
        short='w',
        long="width",
        about="bubble width",
        env="COW_WIDTH",
        default_values=["40"],
      ),
      @argparse.OptionArg(
        "eyes",
        short='e',
        long="eyes",
        about="two-character eyes",
        default_values=["oo"],
      ),
      @argparse.OptionArg("tongue", long="tongue", about="cow tongue", default_values=[
        "  ",
      ]),
    ],
    positionals=[
      @argparse.PositionArg(
        "message",
        about="message words; stdin is used when omitted",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("cow: failed to read argv: \{err}", 2)
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
fn values(matches : @argparse.Matches, name : String) -> Array[String] {
  matches.values.get(name).unwrap_or([])
}

///|
fn value(
  matches : @argparse.Matches,
  name : String,
  fallback : String,
) -> String {
  match matches.values.get(name) {
    Some(items) =>
      match items.get(0) {
        Some(item) => item
        None => fallback
      }
    None => fallback
  }
}

///|
fn int_value(matches : @argparse.Matches, name : String, fallback : Int) -> Int {
  @string.parse_int(value(matches, name, fallback.to_string())) catch {
    _ => fallback
  }
}

///|
fn normalize_pair(text : String, fill : Char) -> String {
  if text.length() >= 2 {
    text[:2].to_owned()
  } else {
    text.pad_end(2, fill)
  }
}

///|
fn input_message(matches : @argparse.Matches) -> String {
  let words = values(matches, "message")
  if words.is_empty() {
    let input = @miniio.stdin.read_all().text() catch {
        err => die("cow: failed to read stdin: \{err}", 1)
      }
    let trimmed = input.trim().to_owned()
    if trimmed.is_empty() {
      "portable wasm cli"
    } else {
      trimmed
    }
  } else {
    words.join(" ")
  }
}

///|
fn wrap_line(line : StringView, width : Int, lines : Array[String]) -> Unit {
  let words = line.split(" ").filter(word => !word.is_empty()).to_array()
  if words.is_empty() {
    lines.push("")
    return
  }
  let mut current = ""
  for word_view in words {
    let word = word_view.to_owned()
    if current.is_empty() {
      current = word
    } else if current.length() + 1 + word.length() <= width {
      current = current + " " + word
    } else {
      lines.push(current)
      current = word
    }
  }
  lines.push(current)
}

///|
fn wrap_text(text : String, width : Int) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    wrap_line(line, width, lines)
  }
  lines
}

///|
fn bubble_line(
  left : String,
  text : String,
  right : String,
  width : Int,
) -> String {
  left + " " + text.pad_end(width, ' ') + " " + right + "\n"
}

///|
fn render_bubble(lines : Array[String]) -> String {
  let mut width = 0
  for line in lines {
    width = width.max(line.length())
  }
  let out = StringBuilder()
  out.write_string(" " + "_".repeat(width + 2) + "\n")
  if lines.length() == 1 {
    out.write_string(bubble_line("<", lines[0], ">", width))
  } else {
    for i in 0..<lines.length() {
      if i == 0 {
        out.write_string(bubble_line("/", lines[i], "\\", width))
      } else if i == lines.length() - 1 {
        out.write_string(bubble_line("\\", lines[i], "/", width))
      } else {
        out.write_string(bubble_line("|", lines[i], "|", width))
      }
    }
  }
  out.write_string(" " + "-".repeat(width + 2) + "\n")
  out.to_string()
}

///|
fn render_cow(think : Bool, eyes : String, tongue : String) -> String {
  let tail = if think { "o" } else { "\\" }
  "        \{tail}   ^__^\n" +
  "         \{tail}  (\{eyes})\\_______\n" +
  "            (__)\\       )\\/\\\n" +
  "             \{tongue} ||----w |\n" +
  "                ||     ||\n"
}

///|
fn main {
  let matches = parse()
  let width = int_value(matches, "width", 40).clamp(min=10, max=80)
  let lines = wrap_text(input_message(matches), width)
  let eyes = normalize_pair(value(matches, "eyes", "oo"), 'o')
  let tongue = normalize_pair(value(matches, "tongue", "  "), ' ')
  @miniio.stdout.write_text(
    render_bubble(lines) + render_cow(flag(matches, "think"), eyes, tongue),
  ) catch {
    err => die("cow: failed to write stdout: \{err}", 1)
  }
}
