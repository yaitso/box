#!/usr/bin/env nu

defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '
<dict>
  <key>enabled</key>
  <true/>
  <key>value</key>
  <dict>
    <key>type</key>
    <string>standard</string>
    <key>parameters</key>
    <array>
      <integer>65535</integer>
      <integer>79</integer>
      <integer>0</integer>
    </array>
  </dict>
</dict>
'

def browser_shortcuts [bundle_id: string] {
  defaults write $bundle_id NSUserKeyEquivalents -dict-add "Duplicate Tab" "@$d"
  defaults write $bundle_id NSUserKeyEquivalents -dict-add "New Tab" "~t"
  defaults write $bundle_id NSUserKeyEquivalents -dict-add "Bookmark All Tabs..." "~$d"
  defaults write $bundle_id NSUserKeyEquivalents -dict-add "New Tab to the Right" "@t"
}

browser_shortcuts "net.imput.helium"
browser_shortcuts "com.brave.Browser"

let brave_running = (ps | where name =~ "(?i)brave" | is-not-empty)
let helium_running = (ps | where name =~ "(?i)helium" | is-not-empty)

if $brave_running {
  print "⚠ brave is running — shortcuts won't apply until you quit (⌘Q) and reopen"
}
if $helium_running {
  print "⚠ helium is running — shortcuts won't apply until you quit (⌘Q) and reopen"
}

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
