///|
struct Entry {
  name : String
  path : String
  is_dir : Bool
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
    "tree",
    about="Render a deterministic directory tree over WASIp1 preopened paths.",
    version="0.1.0",
    flags=[
      @argparse.FlagArg(
        "all",
        short='a',
        long="all",
        about="include hidden entries",
      ),
      @argparse.FlagArg(
        "dirs-only",
        short='d',
        long="dirs-only",
        about="show directories only",
      ),
    ],
    options=[
      @argparse.OptionArg(
        "depth",
        short='L',
        long="depth",
        about="maximum recursion depth",
        env="TREE_DEPTH",
        default_values=["4"],
      ),
    ],
    positionals=[
      @argparse.PositionArg("path", about="root path", default_values=["."]),
    ],
  )
}

///|
fn parse() -> @argparse.Matches {
  let args = @miniio.args_get() catch {
    err => die("tree: failed to read argv: \{err}", 2)
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
fn path_join(parent : String, child : String) -> String {
  if parent == "" || parent == "." {
    child
  } else if parent.has_suffix("/") {
    parent + child
  } else {
    parent + "/" + child
  }
}

///|
fn collect_children(
  path : String,
  include_hidden : Bool,
  dirs_only : Bool,
) -> Array[Entry] {
  let names = @miniio.readdir(path, include_hidden~, sort=true) catch {
    _ => return []
  }
  let children : Array[Entry] = []
  for name in names {
    let child_path = path_join(path, name)
    let is_dir = @miniio.is_dir(child_path) catch { _ => false }
    if !dirs_only || is_dir {
      children.push(Entry::{ name, path: child_path, is_dir })
    }
  }
  children
}

///|
fn walk(
  path : String,
  prefix : String,
  depth : Int,
  max_depth : Int,
  include_hidden : Bool,
  dirs_only : Bool,
  out : StringBuilder,
) -> Unit {
  if depth >= max_depth {
    return
  }
  let children = collect_children(path, include_hidden, dirs_only)
  for i in 0..<children.length() {
    let child = children[i]
    let last = i == children.length() - 1
    let branch = if last { "`-- " } else { "|-- " }
    let suffix = if child.is_dir { "/" } else { "" }
    out.write_string(prefix + branch + child.name + suffix + "\n")
    if child.is_dir {
      let next = if last { "    " } else { "|   " }
      walk(
        child.path,
        prefix + next,
        depth + 1,
        max_depth,
        include_hidden,
        dirs_only,
        out,
      )
    }
  }
}

///|
fn main {
  let matches = parse()
  let path = value(matches, "path", ".")
  let max_depth = int_value(matches, "depth", 4).clamp(min=0, max=64)
  let out = StringBuilder()
  let root_suffix = if (@miniio.is_dir(path) catch { _ => false }) {
    "/"
  } else {
    ""
  }
  out.write_string(path + root_suffix + "\n")
  walk(
    path,
    "",
    0,
    max_depth,
    flag(matches, "all"),
    flag(matches, "dirs-only"),
    out,
  )
  @miniio.stdout.write_text(out.to_string()) catch {
    err => die("tree: failed to write stdout: \{err}", 1)
  }
}
