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

defaults write net.imput.helium NSUserKeyEquivalents -dict-add "Duplicate Tab" "@$d"
defaults write net.imput.helium NSUserKeyEquivalents -dict-add "New Tab" "~t"
defaults write net.imput.helium NSUserKeyEquivalents -dict-add "Bookmark All Tabs..." "~$d"
defaults write net.imput.helium NSUserKeyEquivalents -dict-add "New Tab to the Right" "@t"

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
