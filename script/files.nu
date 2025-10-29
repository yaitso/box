#!/usr/bin/env nu

let before = (date now)
let box_root = ($env.BOX_ROOT? | default ($env.HOME | path join "box"))
let home_box = $env.HOME | path join "box"
if not ($home_box | path exists) {
  ^ln -sfn $box_root $home_box
} else if (($home_box | path type) == "symlink") {
  ^ln -sfn $box_root $home_box
}

let nu_dir = if ($nu.os-info.name == "macos") {
  "Library/Application Support/nushell"
} else {
  ".config/nushell"
}

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
