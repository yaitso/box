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

let graalpy_path = $env.HOME | path join ".local/share/uv/python"
if ($graalpy_path | path exists) {
  let graalpy_bin = ls $graalpy_path
    | where name =~ "graalpy-"
    | get name.0?
    | path join "bin/graalpy"

  if ($graalpy_bin | path exists) {
    let bin_dir = $env.HOME | path join ".local/bin"
    ^mkdir -p $bin_dir
    ^ln -sf $graalpy_bin ($bin_dir | path join "graalpy")
    print $"[files] linked graalpy to ($bin_dir)/graalpy"
  }
}
