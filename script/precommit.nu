#!/usr/bin/env nu

use shared.nu [run has]

let root = ($env.HOME | path join "box")
cd $root

if ("env.nix" | path exists) {
  ^git reset HEAD env.nix out+err> /dev/null
  ^rm -f env.nix
}

if ("script/secret.nu" | path exists) {
  print "[precommit] check secrets"
  ^nu script/secret.nu
}

let tmpfile = (mktemp -t precommit.XXXXXX)

print "[precommit] format nix"
run nixfmt [nixfmt flake.nix shared.nix macos.nix linux.nix] $tmpfile --skip-if-missing

print "[precommit] format shell"
run shfmt [shfmt -w -s -i 2 setup.sh] $tmpfile --skip-if-missing

print "[precommit] shellcheck"
run shellcheck [shellcheck -x setup.sh] $tmpfile --skip-if-missing

print "[precommit] format swift"
run swiftformat [swiftformat kount] $tmpfile --skip-if-missing

print "[precommit] format json"
if (has jq) {
  let json_files = (glob **/*.json | where { |f| $f !~ "node_modules" })
  for file in $json_files {
    ^jq -S . $file | save -f $file
  }
}

print "[precommit] format toml"
if (has taplo) {
  let toml_files = (glob **/*.toml)
  for file in $toml_files {
    ^taplo fmt $file
  }
}

print "[precommit] done"
