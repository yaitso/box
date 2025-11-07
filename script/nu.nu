export alias cmd = cursor ~/.claude/CLAUDE.md
export alias claude = ^claude --dangerously-skip-permissions
export alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
export alias h = hx
export alias c = claude
export alias co = codex
export alias ns = nix-shell

export def raw [...args] {
  ^claude --dangerously-skip-permissions --setting-sources "" --strict-mcp-config ...$args
}

export def ai [...args] {
  if ($args | is-empty) {
    print "usage: ai <question> or ai <question> <schema>"
    return
  }
  
  let has_schema = ($args | length) == 2
  let question = if $has_schema { $args.0 } else { $args | str join ' ' }
  let schema = if $has_schema { $args.1 } else { "" }
  let is_tty = (^tty | complete | get exit_code) == 0
  
  if $is_tty {
    print -n (ansi cursor_off) --stderr
    ^bash -c 'while true; do for s in ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; do printf "\r%s" "$s" >&2; sleep 0.1; done; done &'
  }
  
  let base_args = ["--dangerously-skip-permissions" "--setting-sources" "" "--strict-mcp-config" "-p" "--output-format" "json"]
  let schema_args = if $has_schema {
    let sys = "You are a JSON generator. You MUST respond with ONLY raw JSON that validates against the provided schema. NO explanations. NO markdown. NO code fences. ONLY the JSON object itself."
    ["--system-prompt" $sys "--append-system-prompt" $"Schema: ($schema)"]
  } else {
    []
  }
  
  let result = ($question | ^claude ...$base_args ...$schema_args | complete)
  
  if $is_tty {
    ^bash -c 'pkill -f "while true.*⠋"' out+err>| ignore
    print -n $"\r(ansi erase_entire_line)(ansi cursor_on)" --stderr
  }
  
  if $result.exit_code != 0 {
    print $"error: ($result.stderr)"
    return
  }
  
  let raw_output = ($result.stdout | lines | each {|line| 
    try { $line | from json | where type == "result" | get result.0 } catch { null }
  } | where $it != null | first)
  
  if $has_schema {
    $raw_output | str replace --regex '```json\s*' '' | str replace --regex '\s*```' '' | str trim
  } else {
    $raw_output
  }
}

export def sch [] {
  cd ~/box
  cursor --wait -g schema.py:5:7
  let output = (uv run schema.py | complete)
  print $output.stdout
  $output.stdout | str trim | pbcopy
  git checkout schema.py
}

export alias ls = ls -ald
export def wh [...rest] { which -a ...$rest | uniq }
export def ll [] { ls -ald | sort-by modified }
export def b [...args] { if ($args | is-empty) { ^bash } else { ^bash -c $"($args | str join ' ')" } }
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

export def sk [] {
  bun run dev
}

export use ($nu.default-config-dir | path join "build.nu") *