$env.config = {
  show_banner: false
  hooks: {
    env_change: {
      PWD: [{|before, after|
        if (".envrc" | path exists) {
          direnv export json | from json | default {} | load-env
        }
      }]
    }
  }
}

$env.PROMPT_INDICATOR = ""
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_COMMAND = {
  let pink = (ansi --escape '38;5;211m')
  let yellow = (ansi --escape '38;5;220m')
  let green = (ansi --escape '38;5;79m')
  let purple = (ansi --escape '38;5;177m')
  let reset = (ansi reset)
  let host = (hostname | str trim)
  
  $"($pink)(whoami)($yellow)@($green)($host) ($purple)(pwd)($reset) nu > "
}


$env.BASH_DEFAULT_TIMEOUT_MS = 3600000
$env.BASH_MAX_TIMEOUT_MS = 360000000

alias cmd = ^cursor $"($env.HOME)/.claude/CLAUDE.md"
alias claude = ^claude --dangerously-skip-permissions
alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
alias c = claude
alias co = codex
alias ns = nix-shell
alias py = python3
alias python = python3

alias ls = ls -ald
def which [] { which -a | uniq }
def ll [] { ls -ald | sort-by modified }
def b [...args] { ^bash -c $"($args | str join ' ')" }
def gg [] {
  git add .
  git commit -m "yaitso"
  git push -f
}

use box.nu *
