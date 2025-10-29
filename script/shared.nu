export def has [name: string] { which $name | is-not-empty }

export def run [
  name: string
  cmd: list<string>
  logfile: string
  --skip-if-missing
] {
  if $skip_if_missing and not (has $cmd.0) {
    print $"[skip] missing ($name)"
    return
  }
  
  let result = ^$cmd.0 ...($cmd | skip 1) | complete
  $result.stdout | save --append $logfile
  $result.stderr | save --append $logfile
  
  if $result.exit_code != 0 {
    print $result.stdout
    print $result.stderr
    error make { msg: $"($name) failed" }
  }
}

