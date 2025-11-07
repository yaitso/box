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

# vanilla claude print mode with json output
# examples:
#   rawp "what is 2+2" | jq -r '.[] | select(.type=="result") | .result'
#   → 2 + 2 = 4
#
#   rawp "what is 2+2" | jq -r '.[] | select(.type=="assistant") | .message.content[0].text'
#   → 2 + 2 = 4
#
#   rawp "what is 2+2" | jq '.[] | select(.type=="result") | {result, total_cost_usd, duration_ms}'
#   → {"result": "2 + 2 = 4", "total_cost_usd": 0.0060236, "duration_ms": 2476}
export def rawp [...args] {
  ^claude --dangerously-skip-permissions --setting-sources "" --strict-mcp-config -p --output-format json ...$args
}

# schema.py snippet workflow
# opens cursor at $1 placeholder, fill in class name and fields, save & close
# automatically runs uv run schema.py then resets file back to template
export def sch [] {
  cd ~/box
  cursor --wait -g schema.py:7:7
  uv run schema.py
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