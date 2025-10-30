#!/usr/bin/env nu

let mcp_source = $env.HOME | path join "box/tools/claude.json"
let user_config = $env.HOME | path join ".claude.json"
let project_config = $env.HOME | path join "box/.mcp.json"

if not ($mcp_source | path exists) {
  print "[mcp] source config not found, skipping"
  exit 0
}

let mcp_servers = open $mcp_source | get mcpServers

if ($user_config | path exists) {
  let current = open $user_config
  let updated = $current | upsert mcpServers $mcp_servers
  $updated | save -f $user_config
  print $"[mcp] updated ($user_config)"
}

$mcp_servers | wrap mcpServers | save -f $project_config
print $"[mcp] updated ($project_config)"
