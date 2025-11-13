variable "hcloud_token" {
  description = "hetzner cloud api token"
  type        = string
  sensitive   = true
}

variable "box_username" {
  description = "username for non-root user"
  type        = string
  default     = "yaitso"
}

