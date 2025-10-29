#!/usr/bin/env nu

let before = (date now)

print "[linux] checking for ubuntu vm"
let vms = ^orb list -q | complete
let ubuntu_exists = ($vms.stdout | lines | any {|line| $line =~ "ubuntu"})

if not $ubuntu_exists {
  print "[linux] creating ubuntu:noble vm"
  ^orb create -a arm64 ubuntu:noble ubuntu
  sleep 10sec
  print "[linux] installing unzip in vm"
  ^orb run -m ubuntu sudo apt-get update -qq
  ^orb run -m ubuntu sudo apt-get install -y unzip
}

print "[linux] creating zip of box (excluding .git)"
let box_root = $env.HOME | path join "box"
cd $box_root
^zip -r /tmp/box.zip . -x ".git/*"

print "[linux] copying zip to vm"
^ssh ubuntu@orb "rm -rf ~/box ~/box.zip"
^orb push -m ubuntu /tmp/box.zip

print "[linux] extracting to ~/box in vm"
^ssh ubuntu@orb "cd ~ && unzip -q box.zip -d box && rm box.zip"

print "[linux] running setup.sh in vm"
^ssh ubuntu@orb "cd box && bash setup.sh"

print "[linux] testing whoami"
^ssh ubuntu@orb whoami

print "[linux] testing nushell"
^ssh ubuntu@orb "nu -c 'version'"

let elapsed = (date now) - $before
print $"[linux] completed in ($elapsed)"
