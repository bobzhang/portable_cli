///|
struct WordCount {
  word : String
  count : Int
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
    "pulse",
    about="Read text from a file or stdin and print a compact word histogram.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "preserve-case",
        long="preserve-case",
        about="keep original word case",
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
        "top",
        short='n',
        long="top",
        about="number of words to show",
        default_values=["8"],
      ),
      @argparse.OptionArg(
        "width",
        short='w',
        long="width",
        about="maximum bar width",
        default_values=["24"],
      ),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("pulse: failed to read argv: \{err}", 2)
  }
  let env = @miniio.get_env_vars() catch { _ => {} }
  command().parse(argv=args[1:], env~) catch {
    err => die(err.to_string(), 2)
  }
}

///|
fn flag(matches : @argparse.Matches, name : String, fallback : Bool) -> Bool {
  matches.flags.get(name).unwrap_or(fallback)
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
        err => die("pulse: failed to read \{path}: \{err}", 1)
      }
    None =>
      @miniio.stdin.read_all().text() catch {
        err => die("pulse: failed to read stdin: \{err}", 1)
      }
  }
}

///|
fn word_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '\''
}

///|
fn add_word(
  words : Map[String, Int],
  current : StringBuilder,
  lowercase : Bool,
) -> Unit {
  if current.is_empty() {
    return
  }
  let raw = current.to_string()
  current.reset()
  let word = if lowercase { raw.to_lower() } else { raw }
  words[word] = words.get(word).unwrap_or(0) + 1
}

///|
fn count_words(text : String, lowercase : Bool) -> Map[String, Int] {
  let words : Map[String, Int] = {}
  let current = StringBuilder()
  for ch in text {
    if word_char(ch) {
      current.write_char(ch)
    } else {
      add_word(words, current, lowercase)
    }
  }
  add_word(words, current, lowercase)
  words
}

///|
fn sorted_counts(words : Map[String, Int]) -> Array[WordCount] {
  let items : Array[WordCount] = []
  for entry in words.to_array() {
    items.push(WordCount::{ word: entry.0, count: entry.1 })
  }
  items.sort_by((left, right) => {
    let by_count = right.count.compare(left.count)
    if by_count != 0 {
      by_count
    } else {
      left.word.compare(right.word)
    }
  })
  items
}

///|
fn line_count(text : String) -> Int {
  if text.is_empty() {
    return 0
  }
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  if text.has_suffix("\n") {
    count
  } else {
    count + 1
  }
}

///|
fn render_bar(count : Int, max_count : Int, width : Int) -> String {
  let n = if max_count == 0 { 0 } else { (count * width / max_count).max(1) }
  "#".repeat(n)
}

///|
fn render(text : String, lowercase : Bool, top : Int, width : Int) -> String {
  let words = count_words(text, lowercase)
  let items = sorted_counts(words)
  let max_count = match items.get(0) {
    Some(item) => item.count
    None => 0
  }
  let out = StringBuilder()
  out.write_string("chars: \{text.char_length()}\n")
  out.write_string("lines: \{line_count(text)}\n")
  out.write_string(
    "words: \{items.fold(init=0, (acc, item) => acc + item.count)}\n",
  )
  out.write_string("unique: \{items.length()}\n")
  out.write_string("\n")
  out.write_string("top words:\n")
  let limit = top.min(items.length())
  for i in 0..<limit {
    let item = items[i]
    let label = item.word.pad_end(14, ' ')
    out.write_string(
      label +
      " " +
      item.count.to_string().pad_start(4, ' ') +
      " " +
      render_bar(item.count, max_count, width) +
      "\n",
    )
  }
  out.to_string()
}

///|
fn main {
  let matches = parse()
  let lowercase = !flag(matches, "preserve-case", false)
  let top = int_value(matches, "top", 8).clamp(min=0, max=50)
  let width = int_value(matches, "width", 24).clamp(min=1, max=80)
  @miniio.stdout.write_text(render(read_input(matches), lowercase, top, width)) catch {
    err => die("pulse: failed to write stdout: \{err}", 1)
  }
}
