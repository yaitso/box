#!/usr/bin/env nu

use shared.nu run

let root = ($env.HOME | path join "box")
cd $root

let tmpfile = (mktemp -t precommit.XXXXXX)

print "[precommit] format nix"
run nixfmt [nixfmt flake.nix shared.nix macos.nix linux.nix] $tmpfile --skip-if-missing

print "[precommit] format shell"
run shfmt [shfmt -w -s -i 2 setup.sh] $tmpfile --skip-if-missing

print "[precommit] shellcheck"
run shellcheck [shellcheck -x setup.sh] $tmpfile --skip-if-missing

print "[precommit] format swift"
run swiftformat [swiftformat kount] $tmpfile --skip-if-missing

print "[precommit] done"
