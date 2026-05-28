output "vpc_id" {
  value = huaweicloud_vpc.main.id
}

output "cluster_id" {
  value = huaweicloud_cce_cluster.main.id
}

output "cluster_endpoint" {
  value = jsondecode(huaweicloud_cce_cluster.main.kube_config_raw).clusters[0].cluster.server
}

output "kubeconfig" {
  value     = data.huaweicloud_cce_cluster.main.kube_config_raw
  sensitive = true
}

output "public_ip" {
  value = huaweicloud_vpc_eip.main.address
}

output "security_group_id" {
  value = huaweicloud_networking_secgroup.main.id
}

output "ssh_private_key" {
  description = "SSH private key for accessing CCE nodes (auto-generated when key_pair_name is empty)"
  value       = length(tls_private_key.main) > 0 ? tls_private_key.main[0].private_key_pem : ""
  sensitive   = true
}

output "subnet_cidr_id" {
  description = "VPC subnet cidr id"
  value       = huaweicloud_vpc_subnet.main[0].cidr
}

output "registry_organization" {
  description = "Registry organization name"
  value       = huaweicloud_swr_organization.main.name
}

output "registry_repository_name" {
  description = "Registry repository name"
  value       = huaweicloud_swr_repository.main.name
}

output "registry_inner_pull_url" {
  description = "Internal network pull image address of the registry"
  value       = "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
}

output "registry_external_push_url" {
  description = "External network push mirror address"
  value       = "swr-api.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
}

output "registry_login_command" {
  description = "Registry docker login command"
  value       = huaweicloud_swr_temporary_login_command.main.x_swr_docker_login
  sensitive   = true
}

output "registry_auth_info" {
  description = "Registry auth info"
  value = {
    organization      = huaweicloud_swr_organization.main.name
    repository        = huaweicloud_swr_repository.main.name
    inner_pull_url    = "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
    external_push_url = "swr-api.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
    region            = var.region
    provider          = "huaweicloud"
    auth              = huaweicloud_swr_temporary_login_command.main.x_swr_docker_login
    auth_expire_at    = huaweicloud_swr_temporary_login_command.main.x_expire_at
    auth_description  = "⚠️ This authentication is temporary (expire at ${huaweicloud_swr_temporary_login_command.main.x_expire_at}). After deployment, please be sure to update it with long-term valid authentication information to avoid being unable to pull the image due to authentication expiration."
  }
  sensitive = true
}
