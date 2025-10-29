#!/usr/bin/env nu

def main [--clean] {
  let before = (date now)

  print "[linux] checking for ubuntu vm"
  let vms = ^orb list -q | complete
  let ubuntu_exists = ($vms.stdout | lines | any {|line| $line =~ "ubuntu"})

  if $clean and $ubuntu_exists {
    print "[linux] deleting existing vm (--clean)"
    ^orb delete ubuntu -f
    let ubuntu_exists = false
  }

  if not $ubuntu_exists {
    print "[linux] creating ubuntu:noble vm"
    ^orb create -a arm64 ubuntu:noble ubuntu
    sleep 10sec
    
    print "[linux] fixing hostname resolution"
    ^ssh ubuntu@orb "echo '127.0.0.1 linux' | sudo tee -a /etc/hosts >/dev/null"
    
    print "[linux] installing unzip in vm"
    ^ssh ubuntu@orb "sudo apt-get update -qq && sudo apt-get install -y unzip"
  }

  print "[linux] creating zip of box (excluding .git)"
  let box_root = $env.HOME | path join "box"
  cd $box_root
  ^zip -r /tmp/box.zip . -x ".git/*"

  print "[linux] copying zip to vm via scp"
  ^ssh ubuntu@orb "rm -rf ~/box ~/box.zip"
  ^scp /tmp/box.zip ubuntu@orb:~/

  print "[linux] extracting to ~/box in vm"
  ^ssh ubuntu@orb "bash -c 'unzip -q ~/box.zip -d ~/box && rm ~/box.zip'"

  print "[linux] running setup.sh in vm"
  ^ssh ubuntu@orb "bash -c 'cd box && bash setup.sh'"

  let elapsed = (date now) - $before
  print $"[linux] completed in ($elapsed)"
}
