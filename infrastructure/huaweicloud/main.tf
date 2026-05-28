resource "huaweicloud_vpc" "main" {
  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  tags = var.tags
}

resource "huaweicloud_vpc_subnet" "main" {
  count             = length(var.availability_zones)
  name              = "${var.cluster_name}-subnet-${count.index}"
  cidr              = cidrsubnet(var.vpc_cidr, 8, count.index)
  gateway_ip        = cidrhost(cidrsubnet(var.vpc_cidr, 8, count.index), 1)
  vpc_id            = huaweicloud_vpc.main.id
  availability_zone = var.availability_zones[count.index]
  tags              = var.tags
}

resource "huaweicloud_networking_secgroup" "main" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for TapData K8S cluster"
}

resource "huaweicloud_networking_secgroup_rule" "port_3030" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3030
  port_range_max    = 3030
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.main.id
}

resource "huaweicloud_networking_secgroup_rule" "internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.vpc_cidr
  security_group_id = huaweicloud_networking_secgroup.main.id
}

resource "tls_private_key" "main" {
  count     = var.key_pair_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "huaweicloud_compute_keypair" "main" {
  count      = var.key_pair_name == "" ? 1 : 0
  name       = "${var.cluster_name}-keypair"
  public_key = tls_private_key.main[0].public_key_openssh
}

resource "time_sleep" "wait_for_subnet" {
  create_duration = "30s"
  depends_on      = [huaweicloud_vpc_subnet.main]
}

resource "huaweicloud_cce_cluster" "main" {
  name                   = var.cluster_name
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.28"
  flavor_id              = "cce.s1.small"
  vpc_id                 = huaweicloud_vpc.main.id
  subnet_id              = huaweicloud_vpc_subnet.main[0].id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac"
  kube_proxy_mode        = "ipvs"
  delete_all             = true
  eip                    = huaweicloud_vpc_eip.main.address

  tags = var.tags

  depends_on = [time_sleep.wait_for_subnet]
}

resource "huaweicloud_cce_node_pool" "main" {
  cluster_id         = huaweicloud_cce_cluster.main.id
  name               = "${var.cluster_name}-node-pool"
  os                 = "EulerOS 2.9"
  flavor_id          = var.node_flavor != "" ? var.node_flavor : "s6.large.2"
  initial_node_count = var.node_count
  # availability_zone  = var.availability_zones[0]
  key_pair     = var.key_pair_name != "" ? var.key_pair_name : huaweicloud_compute_keypair.main[0].name
  scall_enable = false

  root_volume {
    size       = 50
    volumetype = "SAS"
  }

  data_volumes {
    size       = 100
    volumetype = "SAS"
  }
}

resource "huaweicloud_vpc_eip" "main" {
  name = "${var.cluster_name}-eip"

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.cluster_name}-bandwidth"
    size        = 10
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_vpc_eip" "nat" {
  name = "${var.cluster_name}-nat-eip"

  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.cluster_name}-nat-bandwidth"
    size        = 10
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_nat_gateway" "main" {
  name                  = "${var.cluster_name}-nat"
  description           = "NAT gateway for CCE nodes to access internet"
  vpc_id                = huaweicloud_vpc.main.id
  subnet_id             = huaweicloud_vpc_subnet.main[0].id
  spec                  = "1"
  enterprise_project_id = "0"

  depends_on = [huaweicloud_vpc_eip.nat]
}

resource "huaweicloud_nat_snat_rule" "main" {
  count          = length(var.availability_zones)
  nat_gateway_id = huaweicloud_nat_gateway.main.id
  cidr           = cidrsubnet(var.vpc_cidr, 8, count.index)
  source_type    = 0
  floating_ip_id = huaweicloud_vpc_eip.nat.id

  depends_on = [huaweicloud_nat_gateway.main]
}

data "huaweicloud_cce_cluster" "main" {
  id = huaweicloud_cce_cluster.main.id
}

# Registry Organization (SWR for Huawei Cloud)
resource "huaweicloud_swr_organization" "main" {
  name = var.registry_organization != "" ? var.registry_organization : var.cluster_name
}

# Registry Repository (SWR for Huawei Cloud)
resource "huaweicloud_swr_repository" "main" {
  organization = huaweicloud_swr_organization.main.name
  name         = var.registry_repository_name != "" ? var.registry_repository_name : var.cluster_name
  description  = "TapData container image repository"
  category     = "app_server"
  is_public    = false
}
