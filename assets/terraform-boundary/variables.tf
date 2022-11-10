variable "boundary_addr" {
  type = string
}
variable "auth_method_id" {
  type = string
}

variable "vault_token" {
  type = string
}

variable "users" {
  type = set(string)
  default = [
    "John",
    "Doug",
    "Steve"
  ]
}

variable "readonly_users" {
  type = set(string)
  default = [
    "Chris"
  ]
}

variable "backend_linux_server_ips" {
  type = set(string)
  default = [
    "vault-sql-server",
  ]
}

variable "windows_server_ips" {
  type = set(string)
  default = [
    "windows-server",
  ]
}

# variable "K8s_server_ips" {
#   type = set(string)
#   default = [
#     "kubernetes",
#   ]
# }