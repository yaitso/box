#!/usr/bin/env nu

let before = (date now)
let box_root = $env.HOME | path join "box"
let nu_dir = $nu.default-config-dir | path relative-to $env.HOME

let files = [
  { src: "tools/vim", dst: ".vimrc" }
  { src: "tools/theme/black", dst: ".vim/colors/black.vim" }
  { src: "tools/theme/black.toml", dst: ".config/helix/themes/black.toml" }
  { src: "tools/ssh", dst: ".ssh/config" }
  { src: "tools/karabiner.json", dst: ".config/karabiner/karabiner.json" }
  { src: "tools/helix.toml", dst: ".config/helix/config.toml" }
  { src: "tools/ghostty", dst: ".config/ghostty/config" }
  { src: "tools/cursor/settings.json", dst: "Library/Application Support/Cursor/User/settings.json" }
  { src: "tools/cursor/python.json", dst: "Library/Application Support/Cursor/User/snippets/python.json" }
  { src: "tools/cursor/keybindings.json", dst: "Library/Application Support/Cursor/User/keybindings.json" }
  { src: "tools/codex.toml", dst: ".codex/config.toml" }
  { src: "script/build.nu", dst: $"($nu_dir)/build.nu" }
  { src: "script/nu.nu", dst: $"($nu_dir)/nu.nu" }
  { src: "script/shell.nu", dst: $"($nu_dir)/shell.nu" }
  { src: "script/br", dst: ".local/bin/br" }
  { src: "GLOBAL.md", dst: ".codex/AGENTS.md" }
  { src: "GLOBAL.md", dst: ".claude/CLAUDE.md" }
]

for file in $files {
  let src_path = $box_root | path join $file.src
  let dst_path = $env.HOME | path join $file.dst
  let dst_dir = $dst_path | path dirname

  ^mkdir -p $dst_dir
  ^ln -sf $src_path $dst_path
  print $"[files] link ($src_path) to ($dst_path)"
}

let count = $files | length
let elapsed = ((date now) - $before)
print $"[files] linked ($count) config files in ($elapsed)"

let uv_python_path = $env.HOME | path join ".local/share/uv/python"
let bin_dir = $env.HOME | path join ".local/bin"
^mkdir -p $bin_dir

if ($uv_python_path | path exists) {
  let graalpy_bin = ls $uv_python_path
    | where name =~ "graalpy-"
    | get name.0?
    | path join "bin/graalpy"

  if ($graalpy_bin | path exists) {
    ^ln -sf $graalpy_bin ($bin_dir | path join "graal")
    print $"[files] linked graalpy to ($bin_dir)/graal"
  }

  let python314_bin = ls $uv_python_path
    | where name =~ "cpython-3.14"
    | get name.0?
    | path join "bin/python3.14"

  if ($python314_bin | path exists) {
    ^ln -sf $python314_bin ($bin_dir | path join "py")
    ^ln -sf $python314_bin ($bin_dir | path join "python")
    ^ln -sf $python314_bin ($bin_dir | path join "python3")
    ^ln -sf $python314_bin ($bin_dir | path join "python3.14")
    print $"[files] linked python to ($bin_dir)/python"
  }
}
