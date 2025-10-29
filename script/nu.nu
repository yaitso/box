export alias cmd = ^cursor $"($env.HOME)/.claude/CLAUDE.md"
export alias claude = ^claude --dangerously-skip-permissions
export alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
export alias c = claude
export alias co = codex
export alias ns = nix-shell
export alias py = python3
export alias python = python3

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

export use build.nu *