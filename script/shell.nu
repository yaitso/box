$env.config = {
  show_banner: false
  hooks: {
    env_change: {
      PWD: [
        {|before, after|
          if (".envrc" | path exists) {
            direnv export json | from json | default {} | load-env
          }
        }
        {
          condition: {|before, after|
            (".venv/bin/activate.nu" | path exists) and (overlay list | find "activate" | is-empty)
          }
          code: "overlay use .venv/bin/activate.nu"
        }
      ]
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

use ($nu.default-config-dir | path join "nu.nu") *
