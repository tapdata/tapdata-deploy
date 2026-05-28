terraform {
  required_version = ">= 1.0"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = ">= 1.91.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
