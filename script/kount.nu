#!/usr/bin/env nu

use shared.nu run

let before = (date now)
let root = $env.HOME | path join "box" "kount"
let tmpfile = (mktemp -t kount.XXXXXX)
cd $root

print "[kount] generating xcode project"
run "tuist generate" [tuist generate --no-open] $tmpfile

print "[kount] building release binary"
run "xcodebuild" [xcodebuild -workspace kount.xcworkspace -scheme kount -configuration Release clean build CODE_SIGN_IDENTITY=yaitso] $tmpfile

let app_path = glob ($env.HOME | path join "Library/Developer/Xcode/DerivedData/*/Build/Products/Release/kount.app") | first | default ""

if $app_path == "" { error make { msg: "could not find built app" } }

^pkill -x kount | complete
^pkill -x Kount | complete
sleep 1sec

let dest = "/Applications/kount.app"
^rm -rf $dest | complete
^ln -s $app_path $dest

print $"[kount] launching ($dest)"
^open $dest
sleep 2sec

if (^pgrep -x kount | complete | get exit_code) != 0 {
  error make { msg: "kount failed to start" }
}

let elapsed = (date now) - $before
print $"[kount] rebuilt and launched in ($elapsed)"

