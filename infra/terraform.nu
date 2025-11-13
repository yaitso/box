export def tfa [] {
  cd ~/box/infra
  let env_file = ("~/box/.env" | path expand)

  load-env (open $env_file | lines | parse "{key}={value}" | transpose -r | into record)

  ^tofu apply -auto-approve

  print "waiting for cloud-init to complete..."
  sleep 2min

  let ip = (^tofu output -raw server_ip)
  ^ssh -o ConnectTimeout=15 -o IdentitiesOnly=yes -i ~/.ssh/yaitso $"yaitso@($ip)" "sudo cloud-init status --wait"

  print $"✓ server ready at ($ip)"
  print "connect with: ssh h"
}

export def tfp [] {
  cd ~/box/infra
  let env_file = ("~/box/.env" | path expand)

  load-env (open $env_file | lines | parse "{key}={value}" | transpose -r | into record)

  ^tofu plan
}
