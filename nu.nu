source ~/box/infra/terraform.nu

export alias cmd = ^cursor $"($env.HOME)/.claude/CLAUDE.md"
export alias claude = ^claude --dangerously-skip-permissions
export alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
export alias h = helix
export alias c = claude
export alias co = codex
export alias ns = nix-shell
export alias py = python3.14
export alias python = python3.14
export alias python3 = python3.14
export alias macpm = mac

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
  
  if (gh repo view $"yaitso/($name)" | complete | get exit_code) == 0 {
    gh repo delete $"yaitso/($name)" --yes
  }
  
  mkdir $name
  cd $name
  git init
  git branch -M master
  gh repo create $name --private --source=. --remote=origin
  git commit --allow-empty -m "init"
  git push -u origin master
}
