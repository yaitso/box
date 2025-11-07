export alias cmd = cursor ~/.claude/CLAUDE.md
export alias claude = ^claude --dangerously-skip-permissions
export alias codex = ^codex --dangerously-bypass-approvals-and-sandbox --search
export alias h = hx
export alias c = claude
export alias co = codex
export alias ns = nix-shell

# vanilla claude (no CLAUDE.md, no MCP)
export def raw [...args] {
  ^claude --dangerously-skip-permissions --setting-sources "" --strict-mcp-config ...$args
}

export def ai [...args] {
  let question = if ($args | length) == 2 {
    $args.0
  } else if ($args | length) == 1 {
    $args.0
  } else {
    $args | str join ' '
  }
  
  let schema_arg = if ($args | length) == 2 {
    ["--json-schema" $args.1]
  } else {
    []
  }
  
  ^claude --dangerously-skip-permissions --setting-sources "" --strict-mcp-config -p --output-format json ...$schema_arg $question
}

export def sch [] {
  cd ~/box
  cursor --wait -g schema.py:7:7
  let output = (uv run schema.py | complete)
  print $output.stdout
  $output.stdout | pbcopy
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