export def box [
  --verbose
] {
  let args = if $verbose { ["--verbose"] } else { [] }
  bash ($env.HOME | path join "box" "setup.sh") ...$args
}

export def precommit [] {
  nu ($env.HOME | path join "box" "script" "precommit.nu")
}

export def kount [] {
  nu ($env.HOME | path join "box" "script" "kount.nu")
}

export def linux [--clean] {
  if $clean {
    nu ($env.HOME | path join "box" "script" "linux.nu") --clean
  } else {
    nu ($env.HOME | path join "box" "script" "linux.nu")
  }
}

