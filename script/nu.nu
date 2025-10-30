export alias cmd = cursor ~/.claude/CLAUDE.md
export alias claude = ^claude --dangerously-skip-permissions
export alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
export alias h = hx
export alias c = claude
export alias co = codex
export alias ns = nix-shell

export alias ls = ls -ald
export def wh [...rest] { which -a ...$rest | uniq }
export def ll [] { ls -ald | sort-by modified }
export def b [...args] { ^bash -c $"($args | str join ' ')" }
export def gg [] {
  git add .
  git commit -m "yaitso"
  git push -f
}

export def repo [name: string] {
  cd $env.HOME
  mkdir $name
  cd $name
  git init
}

export def mojon [] {
  uv pip install mojo --index-url https://dl.modular.com/public/nightly/python/simple/ --prerelease allow
}

export def mojos [] {
  uv pip install mojo --extra-index-url https://modular.gateway.scarf.sh/simple/
}

export use ($nu.default-config-dir | path join "build.nu") *