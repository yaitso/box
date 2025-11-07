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
            let venv_path = ($after | path join ".venv/bin/activate.nu")
            let expected_venv = ($after | path join ".venv")
            ($venv_path | path exists) and ($env.VIRTUAL_ENV? != $expected_venv)
          }
          code: "overlay use .venv/bin/activate.nu"
        }
      ]
    }
  }
  keybindings: [
    {
      name: accept_suggestion
      modifier: none
      keycode: tab
      mode: [emacs, vi_normal, vi_insert]
      event: { send: historyhintcomplete }
    }
  ]
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
  
  $"($pink)(whoami)($yellow)@($green)($host) ($purple)(pwd)($reset) ❯ "
}

$env.BASH_DEFAULT_TIMEOUT_MS = 3600000
$env.BASH_MAX_TIMEOUT_MS = 360000000

use ($nu.default-config-dir | path join "nu.nu") *
