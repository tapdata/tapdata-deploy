variable "access_key" {
  description = "Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zones" {
  description = "Zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "vpc_cidr" {
  description = "VPC CIDR 块"
  type        = string
  default     = "172.16.0.0/16"
}

variable "cluster_name" {
  description = "kubernetes Cluster Name"
  type        = string
  default     = "tapdata-k8s"
}

variable "node_count" {
  description = "Worker node count"
  type        = number
  default     = 3
}

variable "node_flavor" {
  description = "Node Specifications（flavor_id）"
  type        = string
  default     = "s2.4xlarge.2"
}

variable "key_pair_name" {
  description = "Key pair (It's empty will be created automatically.)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project   = "TapData"
    ManagedBy = "Terraform"
  }
}

variable "registry_organization" {
  description = "Registry organization name (use cluster_name if left blank)"
  type        = string
  default     = ""
}

variable "registry_repository_name" {
  description = "Registry name（use cluster_name if left blank）"
  type        = string
  default     = ""
}
