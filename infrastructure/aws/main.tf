resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

resource "aws_subnet" "main" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.cluster_name}-subnet-${count.index}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-rt"
  })
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table_association" "main" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for TapData K8S cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "TapData port"
    from_port   = 3030
    to_port     = 3030
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Internal VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])

  policy_arn = each.value
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  policy_arn = each.value
  role       = aws_iam_role.node.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids             = aws_subnet.main[*].id
    security_group_ids     = [aws_security_group.main.id]
    endpoint_public_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policies
  ]

  tags = var.tags
}

resource "tls_private_key" "main" {
  count     = var.key_pair_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  count      = var.key_pair_name == "" ? 1 : 0
  key_name   = "${var.cluster_name}-keypair"
  public_key = tls_private_key.main[0].public_key_openssh

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-keypair"
  })
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.main[*].id

  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 2
    min_size     = 1
  }

  instance_types = [var.node_instance_type != "" ? var.node_instance_type : "t3.medium"]

  remote_access {
    ec2_ssh_key               = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.main[0].key_name
    source_security_group_ids = [aws_security_group.main.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policies
  ]

  tags = var.tags
}

resource "aws_eip" "main" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# Registry Repository (ECR for AWS)
resource "aws_ecr_repository" "main" {
  name                 = var.registry_repository_name != "" ? var.registry_repository_name : var.cluster_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

