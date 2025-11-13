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
            let venv_path = ($after | path join ".venv")
            ($venv_path | path exists) and ($env.VIRTUAL_ENV? != $venv_path)
          }
          code: {|before, after|
            let venv_path = ($after | path join ".venv")
            $env.VIRTUAL_ENV = $venv_path
            $env.PATH = ($env.PATH | prepend ($venv_path | path join "bin"))
          }
        }
      ]
    }
  }
  keybindings: [
    {
      name: completion_menu
      modifier: none
      keycode: tab
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          { send: menu name: completion_menu }
          { send: menunext }
        ]
      }
    }
    {
      name: accept_hint_word
      modifier: control
      keycode: right
      mode: [emacs, vi_normal, vi_insert]
      event: { send: historyhintwordcomplete }
    }
    {
      name: accept_hint_full
      modifier: alt
      keycode: right
      mode: [emacs, vi_normal, vi_insert]
      event: { send: historyhintcomplete }
    }
    {
      name: accept_hint_full_ctrl_e
      modifier: control
      keycode: char_e
      mode: [emacs, vi_normal, vi_insert]
      event: { send: historyhintcomplete }
    }
    {
      name: accept_hint_word_alt_e
      modifier: alt
      keycode: char_e
      mode: [emacs, vi_normal, vi_insert]
      event: { send: historyhintwordcomplete }
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
  let grey = (ansi --escape '38;5;245m')
  let reset = (ansi reset)
  let host = (hostname | str trim)

  let venv_prefix = if ($env.VIRTUAL_ENV? != null) {
    let venv_name = ($env.VIRTUAL_ENV | path dirname | path basename)
    $"($grey)\(($venv_name)\)($reset) "
  } else {
    ""
  }

  $"($venv_prefix)($pink)(whoami)($yellow)@($green)($host) ($purple)(pwd)($reset) ❯ "
}

$env.BASH_DEFAULT_TIMEOUT_MS = 3600000
$env.BASH_MAX_TIMEOUT_MS = 360000000

use ($nu.default-config-dir | path join "nu.nu") *
