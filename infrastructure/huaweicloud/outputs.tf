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
  description = "镜像仓库组织名称"
  value       = huaweicloud_swr_organization.main.name
}

output "registry_repository_name" {
  description = "镜像仓库名称"
  value       = huaweicloud_swr_repository.main.name
}

output "registry_inner_pull_url" {
  description = "镜像仓库内网 pull 镜像地址（CCE 节点使用）"
  value       = "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
}

output "registry_external_push_url" {
  description = "镜像仓库外网 push 镜像地址"
  value       = "swr-api.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
}

output "registry_login_command" {
  description = "镜像仓库登录命令"
  value       = "docker login -u ${var.access_key} -p <temporary_token> swr.${var.region}.myhuaweicloud.com"
  sensitive   = true
}

output "registry_auth_info" {
  description = "镜像仓库认证信息"
  value = {
    organization      = huaweicloud_swr_organization.main.name
    repository        = huaweicloud_swr_repository.main.name
    inner_pull_url    = "swr.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
    external_push_url = "swr-api.${var.region}.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
    region            = var.region
    provider          = "huaweicloud"
  }
  sensitive = true
}
