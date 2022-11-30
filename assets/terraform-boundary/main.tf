terraform {
  required_providers {
    boundary = {
      version = "~> 1.1.2"
    }
  }
}

provider "boundary" {
  addr                            = var.boundary_addr
  auth_method_id                  = var.auth_method_id
  password_auth_method_login_name = "admin"
  password_auth_method_password   = "password"
}

resource "boundary_worker" "instruqt_worker" {
  scope_id    = boundary_scope.corp.id
  description = "Dev and Vault Worker"
  name        = "instruqt-worker-dev-vault"
}
output "Worker_token" {
  value = boundary_worker.instruqt_worker.controller_generated_activation_token
}

resource "boundary_scope" "global" {
  global_scope = true
  description  = "My first global scope!"
  scope_id     = "global"
}

resource "boundary_scope" "corp" {
  name                     = "corp_one"
  description              = "My first scope!"
  scope_id                 = boundary_scope.global.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

## Use password auth method
resource "boundary_auth_method" "password" {
  name     = "Corp Password"
  scope_id = boundary_scope.corp.id
  type     = "password"
}

# resource "boundary_auth_method_oidc" "provider" {
#   name               = "Auth0"
#   description        = "OIDC auth method for Auth0"
#   scope_id           = boundary_scope.corp.id                   
#   issuer             = "https://dev-1vdl8c0q.us.auth0.com/"   
#   client_id          = var.    
#   client_secret      = var.   
#   signing_algorithms = ["RS256"]
#   api_url_prefix     = "BOUNDARY_ADDR:9200"                 
#   is_primary_for_scope = true
#   state = "active-public"
#   max_age = 0
#    allowed_audiences  = ["foo_aud"]
#    account_claim_maps = ["oid=sub"]
#    claims_scopes      = ["profile"]
# }
# resource "boundary_account_oidc" "oidc_user" {
#   name           = "user1"
#   description    = "OIDC account for user1"
#   auth_method_id = boundary_auth_method_oidc.provider.id
#   issuer  = "https://dev-1vdl8c0q.us.auth0.com/"            
#   subject = ""
# }
# resource "boundary_managed_group" "oidc_group" {
#   name           = "Auth0"
#   description    = "OIDC managed group for Auth0"
#   auth_method_id = boundary_auth_method_oidc.provider.id
#   filter         = "\"auth0\" in \"/userinfo/sub\""
# }
# output "managed-group-id" {
#   value = boundary_managed_group.oidc_group.id
# }

resource "boundary_account_password" "users_acct" {
  for_each       = var.users
  name           = each.key
  description    = "User account for ${each.key}"
  type           = "password"
  login_name     = lower(each.key)
  password       = "password"
  auth_method_id = boundary_auth_method.password.id
}

resource "boundary_user" "users" {
  for_each    = var.users
  name        = each.key
  description = "User resource for ${each.key}"
  scope_id    = boundary_scope.corp.id
}

resource "boundary_user" "readonly_users" {
  for_each    = var.readonly_users
  name        = each.key
  description = "User resource for ${each.key}"
  scope_id    = boundary_scope.corp.id
}

resource "boundary_group" "readonly" {
  name        = "read-only"
  description = "Organization group for readonly users"
  member_ids  = [for user in boundary_user.readonly_users : user.id]
  scope_id    = boundary_scope.corp.id
}

resource "boundary_role" "organization_readonly" {
  name          = "Read-only"
  description   = "Read-only role"
  principal_ids = [boundary_group.readonly.id]
  grant_strings = ["id=*;type=*;actions=read"]
  scope_id      = boundary_scope.corp.id
}

resource "boundary_role" "organization_admin" {
  name        = "admin"
  description = "Administrator role"
  principal_ids = concat(
    [for user in boundary_user.users : user.id]
  )
  grant_strings = ["id=*;type=*;actions=create,read,update,delete"]
  scope_id      = boundary_scope.corp.id
}

resource "boundary_scope" "core_infra" {
  name                   = "core_infra"
  description            = "My first project!"
  scope_id               = boundary_scope.corp.id
  auto_create_admin_role = true
}


resource "boundary_host_catalog_static" "backend_servers" {
  name        = "backend_servers"
  description = "Backend servers host catalog"
  scope_id    = boundary_scope.core_infra.id
}

resource "boundary_host_static" "backend_linux_servers" {
  for_each        = var.backend_linux_server_ips
  type            = "static"
  name            = "backend_linux_server_service_${each.value}"
  description     = "Backend Linux server host"
  address         = each.key
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
}
resource "boundary_host_static" "backend_windows_servers" {
  for_each        = var.windows_server_ips
  type            = "static"
  name            = "windows_server_service_${each.value}"
  description     = "Backend server host"
  address         = each.key
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
}
# resource "boundary_host_static" "backend_K8s_servers" {
#   for_each        = var.K8s_server_ips
#   type            = "static"
#   name            = "K8s_server_service_${each.value}"
#   description     = "Backend server host"
#   address         = each.key
#   host_catalog_id = boundary_host_catalog_static.backend_K8s_servers.id
# }

resource "boundary_host_set_static" "backend_servers_ssh" {
  type            = "static"
  name            = "backend_servers_ssh"
  description     = "Host set for backend linux servers"
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
  host_ids        = [for host in boundary_host_static.backend_linux_servers : host.id]
}
resource "boundary_host_set_static" "backend_servers_vault" {
  type            = "static"
  name            = "backend_servers_vault"
  description     = "Host set for backend vault servers"
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
  host_ids        = [for host in boundary_host_static.backend_linux_servers : host.id]
}
resource "boundary_host_set_static" "backend_servers_psql" {
  type            = "static"
  name            = "backend_servers_psql"
  description     = "Host set for backend psql servers"
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
  host_ids        = [for host in boundary_host_static.backend_linux_servers : host.id]
}
resource "boundary_host_set_static" "backend_servers_windows" {
  type            = "static"
  name            = "backend_servers_windows"
  description     = "Host set for backend windows servers"
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
  host_ids        = [for host in boundary_host_static.backend_windows_servers : host.id]
}
# resource "boundary_host_set_static" "backend_servers_K8s" {
#   type            = "static"
#   name            = "backend_servers_K8s"
#   description     = "Host set for backend K8s servers"
#   host_catalog_id = boundary_host_catalog_static.backend_servers.id
#   host_ids        = [for host in boundary_host_static.backend_K8s_servers : host.id]
# }

# create target for accessing backend servers on port :22
resource "boundary_target" "backend_servers_ssh_target" {
  type                     = "tcp"
  name                     = "ssh_server"
  description              = "Backend SSH target"
  scope_id                 = boundary_scope.core_infra.id
  default_port             = 22
  session_connection_limit = -1
  session_max_seconds      = 600
  # Add this manually once the provider is updated
  # https://github.com/hashicorp/terraform-provider-boundary/issues/294
  # injected_credential_source_ids = [
  #   boundary_credential_library_vault.postgres_cred_library.id
  # ]
  host_source_ids = [
    boundary_host_set_static.backend_servers_ssh.id
  ]
}
resource "boundary_target" "backend_servers_ssh_brokered" {
  type         = "tcp"
  name         = "ssh_server"
  description  = "Backend SSH target for testing static credential store"
  scope_id     = boundary_scope.core_infra.id
  default_port = 22
  brokered_credential_source_ids = [
    boundary_credential_username_password.example.id,
    boundary_credential_ssh_private_key.example.id
  ]
  host_source_ids = [
    boundary_host_set_static.backend_servers_ssh.id
  ]
}
resource "boundary_target" "backend_servers_psql_target" {
  type                     = "tcp"
  name                     = "postgres_server"
  description              = "Backend postgres target"
  scope_id                 = boundary_scope.core_infra.id
  default_port             = 5432
  session_connection_limit = -1
  brokered_credential_source_ids = [
    boundary_credential_library_vault.postgres_cred_library.id
  ]
  host_source_ids = [
    boundary_host_set_static.backend_servers_psql.id
  ]
}
resource "boundary_target" "backend_servers_vault_target" {
  type                     = "tcp"
  name                     = "vault_server"
  description              = "Backend SSH target"
  scope_id                 = boundary_scope.core_infra.id
  default_port             = 8200
  session_connection_limit = -1
  session_max_seconds      = 600
  host_source_ids = [
    boundary_host_set_static.backend_servers_vault.id
  ]
}
resource "boundary_target" "backend_servers_windows_target" {
  type                     = "tcp"
  name                     = "windows_server"
  description              = "Backend windows target"
  scope_id                 = boundary_scope.core_infra.id
  default_port             = 3389
  session_connection_limit = -1
  session_max_seconds      = 600
  host_source_ids = [
    boundary_host_set_static.backend_servers_windows.id
  ]
}

######################################################################################
# This might have to be done manually of the provider does not support worker filters
# https://github.com/hashicorp/terraform-provider-boundary/issues/294
resource "boundary_credential_store_vault" "postgres_cred_store" {
  name        = "postgres_cred_store"
  description = "Vault credential store for postgres related access"
  address     = "http://vault-sql-server:8200" # change to Vault address
  #worker_filter - Needs to be added
  token    = var.vault_token # change to valid Vault token
  scope_id = boundary_scope.core_infra.id
}
resource "boundary_credential_library_vault" "postgres_cred_library" {
  name                = "postgres_cred_library"
  description         = "Vault credential library for postgres access"
  credential_store_id = boundary_credential_store_vault.postgres_cred_store.id
  path                = "database/creds/vault_go_demo" # change to Vault backend path
  http_method         = "GET"
}
# boundary credential-stores create vault \
#   -scope-id $PROJECT_ID \
#   -vault-address "http://1:8200" \
#   -vault-token $CRED_STORE_TOKEN \
#   -worker-filter='"worker" in "/tags/type"'


#######################################################################################
# Built in credential Store
#
resource "boundary_credential_store_static" "example" {
  name        = "example_static_credential_store"
  description = "My first static credential store!"
  scope_id    = boundary_scope.corp.id
}
resource "boundary_credential_username_password" "example" {
  name                = "example_username_password"
  description         = "My first username password credential!"
  credential_store_id = boundary_credential_store_static.example.id
  username            = "my-username"
  password            = "my-password"
}
resource "boundary_credential_ssh_private_key" "example" {
  name                = "example_ssh_private_key"
  description         = "My first ssh private key credential!"
  credential_store_id = boundary_credential_store_static.example.id
  username            = "root"
  private_key         = file("~/.ssh/id_rsa") # change to valid SSH Private Key
}

