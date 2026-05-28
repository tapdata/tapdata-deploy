output "vpc_id" {
  value = aws_vpc.main.id
}

output "cluster_id" {
  value = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "kubeconfig" {
  description = "kubeconfig with exec mode for auto-refreshing token via aws eks get-token"
  value       = <<-EOT
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
    server: ${aws_eks_cluster.main.endpoint}
  name: ${var.cluster_name}
contexts:
- context:
    cluster: ${var.cluster_name}
    user: ${var.cluster_name}-user
  name: ${var.cluster_name}
current-context: ${var.cluster_name}
kind: Config
preferences: {}
users:
- name: ${var.cluster_name}-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - eks
        - get-token
        - --region
        - ${var.region}
        - --cluster-name
        - ${var.cluster_name}
      env:
        - name: AWS_ACCESS_KEY_ID
          value: ${var.access_key}
        - name: AWS_SECRET_ACCESS_KEY
          value: ${var.secret_key}
EOT
  sensitive   = true
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "public_ip" {
  value = aws_eip.main.public_ip
}

output "security_group_id" {
  value = aws_security_group.main.id
}

output "ssh_private_key" {
  description = "SSH private key for accessing EKS nodes (auto-generated when key_pair_name is empty)"
  value       = length(tls_private_key.main) > 0 ? tls_private_key.main[0].private_key_pem : ""
  sensitive   = true
}

output "registry_organization" {
  description = "镜像仓库组织名称（AWS 使用 AWS 账号 ID）"
  value       = split(":", aws_ecr_repository.main.arn)[4]
}

output "registry_repository_name" {
  description = "镜像仓库名称"
  value       = aws_ecr_repository.main.name
}

output "registry_inner_pull_url" {
  description = "镜像仓库内网 pull 镜像地址（EKS 节点使用）"
  value       = "${split(":", aws_ecr_repository.main.arn)[4]}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.main.name}"
}

output "registry_external_push_url" {
  description = "镜像仓库外网 push 镜像地址"
  value       = "${split(":", aws_ecr_repository.main.arn)[4]}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.main.name}"
}

output "registry_login_command" {
  description = "镜像仓库登录命令"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${split(":", aws_ecr_repository.main.arn)[4]}.dkr.ecr.${var.region}.amazonaws.com"
  sensitive   = true
}

output "registry_auth_info" {
  description = "镜像仓库认证信息"
  value = {
    organization      = split(":", aws_ecr_repository.main.arn)[4]
    repository        = aws_ecr_repository.main.name
    inner_pull_url    = "${split(":", aws_ecr_repository.main.arn)[4]}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.main.name}"
    external_push_url = "${split(":", aws_ecr_repository.main.arn)[4]}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.main.name}"
    region            = var.region
    provider          = "aws"
  }
  sensitive = true
}
