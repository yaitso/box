export def box [
  --update
] {
  let root = $env.HOME | path join "box"

  if $update {
    cd $root
    print "[box] checking for updates"

    ^cp flake.lock flake.lock.old

    print "[box] fetching latest versions"
    ^nix flake update

    print "\n[box] available updates:"

    let changes = ^python3 script/lock.py flake.lock.old flake.lock | str trim

    if ($changes | is-empty) {
      print "  no updates available"
      ^rm -f flake.lock.old
    } else {
      print $changes
      print ""
      let response = input "update? (yes/no) "

      match ($response | str downcase) {
        "yes" | "y" => {
          ^rm -f flake.lock.old
          print "[box] updated — run `box` to rebuild"
        }
        "no" | "n" => {
          ^mv flake.lock.old flake.lock
          print "[box] reverted to previous lock"
        }
        _ => {
          ^mv flake.lock.old flake.lock
          print "[box] invalid response — reverted to previous lock"
        }
      }
    }
  } else {
    bash ($env.HOME | path join "box" "setup.sh")
  }
}

export def precommit [] {
  nu ($env.HOME | path join "box" "script" "precommit.nu")
}

export def kount [] {
  nu ($env.HOME | path join "box" "script" "kount.nu")
}

export def linux [] {
  nu ($env.HOME | path join "box" "script" "linux.nu")
}

