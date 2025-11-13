terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "default" {
  name       = "box-key"
  public_key = file(pathexpand("~/.ssh/yaitso.pub"))
}

resource "hcloud_volume" "data" {
  name     = "box-data"
  size     = 50
  location = "nbg1"
  format   = "ext4"
  labels = {
    managed_by = "tofu"
    project    = "box"
  }
}

resource "hcloud_server" "box" {
  name        = "box"
  server_type = "cax21"
  image       = "ubuntu-24.04"
  location    = "nbg1"
  ssh_keys    = [hcloud_ssh_key.default.id]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    username      = var.box_username
    ssh_key       = file(pathexpand("~/.ssh/yaitso.pub"))
    env_file_b64  = base64encode(file(pathexpand("~/box/.env")))
  })

  labels = {
    managed_by = "tofu"
    project    = "box"
  }
}

resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.box.id
  automount = false
}

resource "null_resource" "update_ssh_config" {
  depends_on = [hcloud_server.box]

  triggers = {
    server_ip = hcloud_server.box.ipv4_address
    username  = var.box_username
  }

  provisioner "local-exec" {
    command = <<-EOT
      SSH_CONFIG="${pathexpand("~/box/tools/ssh.secret")}"

      awk -v ip="${hcloud_server.box.ipv4_address}" -v user="${var.box_username}" '
      /^# ==h==$/ {
        if (!inside) {
          print
          print "Host h"
          print "  HostName " ip
          print "  User " user
          print "  IdentityFile ~/.ssh/yaitso"
          print "  StrictHostKeyChecking accept-new"
          inside=1
          next
        }
      }
      /^# ==h==$/ && inside {
        print
        inside=0
        next
      }
      !inside { print }
      ' "$SSH_CONFIG" > "$SSH_CONFIG.tmp" && mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

output "server_ip" {
  value       = hcloud_server.box.ipv4_address
  description = "public ipv4 address"
}

output "server_status" {
  value = hcloud_server.box.status
}

output "volume_id" {
  value       = hcloud_volume.data.linux_device
  description = "volume device path"
}

output "ssh_connection" {
  value       = "ssh h"
  description = "connect via ssh (config auto-updated)"
}
