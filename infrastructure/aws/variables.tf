variable "region" {
  description = "AWS 区域"
  type        = string
  default     = "ap-southeast-1"
}

variable "access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "VPC CIDR 块"
  type        = string
  default     = "172.16.0.0/16"
}

variable "availability_zones" {
  description = "可用区列表"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "K8S 集群名称"
  type        = string
  default     = "tapdata-k8s"
}

variable "cluster_version" {
  description = "K8S 集群版本"
  type        = string
  default     = "1.35"
}

variable "node_count" {
  description = "工作节点数量"
  type        = number
  default     = 2
}

variable "node_instance_type" {
  description = "节点实例类型（instance_type）"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "密钥对名称"
  type        = string
  default     = ""
}

variable "tags" {
  description = "资源标签"
  type        = map(string)
  default = {
    Project   = "TapData"
    ManagedBy = "Terraform"
  }
}

variable "registry_organization" {
  description = "镜像仓库组织名称（留空则使用 cluster_name）"
  type        = string
  default     = ""
}

variable "registry_repository_name" {
  description = "镜像仓库名称（留空则使用 cluster_name）"
  type        = string
  default     = ""
}
