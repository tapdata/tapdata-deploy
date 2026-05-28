# AWS Infrastructure (EKS)

使用 Terraform 在 AWS 上部署 TapData Kubernetes 集群（EKS）及配套基础设施。

## 前置条件

- Terraform >= 1.0
- AWS 账号及 Access Key / Secret Key
- AWS CLI 已安装并配置
- kubectl 已安装

## 快速开始

### 1. 配置变量

复制并编辑变量文件：

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

主要配置项：

```hcl
region             = "us-east-1"
access_key         = "your-access-key"
secret_key         = "your-secret-key"
availability_zones = ["us-east-1a", "us-east-1b"]
cluster_name       = "tapdata-aws"
node_count         = 2
node_instance_type = "t3.medium"

# 镜像仓库配置（可选，留空则使用 cluster_name）
registry_organization   = ""
registry_repository_name = ""
```

### 2. 初始化 Terraform

```bash
terraform init
```

### 3. 预览和部署

```bash
# 预览变更
terraform plan

# 执行部署
terraform apply
```

### 4. 配置 kubectl

```bash
# 更新 kubeconfig
aws eks update-kubeconfig \
  --region $(terraform output -raw cluster_name | cut -d'"' -f2) \
  --name $(terraform output -raw cluster_name)

# 或使用输出的 kubeconfig
terraform output kubeconfig > ~/.kube/config

# 验证集群连接
kubectl get nodes
```

## 镜像仓库（ECR）配置

### 输出变量说明

部署完成后，会输出以下镜像仓库相关信息：

```bash
# 查看组织名称（AWS 账号 ID）
terraform output registry_organization

# 查看仓库名称
terraform output registry_repository_name

# 查看内网 pull 地址（EKS 节点使用）
terraform output registry_inner_pull_url

# 查看外网 push 地址
terraform output registry_external_push_url

# 查看登录命令
terraform output registry_login_command

# 查看完整认证信息
terraform output registry_auth_info
```

### Docker 登录 ECR

ECR 使用 AWS IAM 认证，需要获取临时令牌：

```bash
# 方式 1：使用 AWS CLI（推荐）
terraform output registry_login_command | sh

# 方式 2：手动执行
REGION="us-east-1"
ACCOUNT_ID=$(terraform output -raw registry_organization)
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
```

**注意**：ECR 登录令牌有效期为 12 小时，过期后需要重新登录。

### 配置 ECR 访问权限

确保 AWS 用户具有以下权限：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    }
  ]
}
```

### 推送镜像到 ECR

```bash
# 1. 构建镜像
docker build -t myapp:v1.0 .

# 2. 标记镜像（使用 ECR 地址）
REGION="us-east-1"
ACCOUNT_ID=$(terraform output -raw registry_organization)
REPO_NAME=$(terraform output -raw registry_repository_name)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

docker tag myapp:v1.0 ${ECR_URL}:v1.0

# 3. 推送镜像
docker push ${ECR_URL}:v1.0
```

**完整示例脚本**：

```bash
#!/bin/bash
set -e

# 获取 ECR 信息
REGION="us-east-1"
ACCOUNT_ID=$(terraform output -raw registry_organization)
REPO_NAME=$(terraform output -raw registry_repository_name)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"
IMAGE_TAG="v1.0"

# 登录 ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_URL}

# 构建并推送镜像
echo "Building image..."
docker build -t myapp:${IMAGE_TAG} .

echo "Tagging image..."
docker tag myapp:${IMAGE_TAG} ${ECR_URL}:${IMAGE_TAG}

echo "Pushing image to ECR..."
docker push ${ECR_URL}:${IMAGE_TAG}

echo "Image pushed successfully: ${ECR_URL}:${IMAGE_TAG}"
```

### 在 EKS 中拉取镜像

EKS 节点通过 IAM Role 自动访问 ECR，无需额外配置 imagePullSecrets。

**Kubernetes 部署示例**：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tapdata
spec:
  template:
    spec:
      containers:
      - name: tapdata
        image: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:latest
        # EKS 节点通过 IAM Role 自动拉取 ECR 镜像，无需 imagePullSecrets
```

**自动脚本获取完整镜像地址**：

```bash
# 获取完整的镜像地址
IMAGE_URL=$(terraform output -raw registry_inner_pull_url)
echo "Use this image URL in your Kubernetes manifests: ${IMAGE_URL}:<tag>"
```

## 基础设施组件

部署包含以下资源：

- **VPC**：虚拟私有云
- **子网**：多可用区子网（带公网 IP）
- **Internet Gateway**：互联网网关
- **安全组**：开放 3030 端口（TapData）及 VPC 内网通信
- **IAM Roles**：EKS 集群和节点角色
- **EKS 集群**：Kubernetes 控制平面
- **EKS 节点组**：工作节点
- **ECR**：容器镜像仓库（含生命周期策略）
- **EIP**：弹性 IP

## 镜像生命周期管理

ECR 仓库已配置生命周期策略，自动保留最近 10 个镜像，避免存储成本无限增长。

查看生命周期策略：

```bash
aws ecr get-lifecycle-policy \
  --repository-name $(terraform output -raw registry_repository_name) \
  --region us-east-1
```

自定义生命周期策略：

```bash
# 编辑策略文件
cat > lifecycle-policy.json << 'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 20 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

# 应用策略
aws ecr put-lifecycle-policy \
  --repository-name $(terraform output -raw registry_repository_name) \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region us-east-1
```

## 清理资源

```bash
terraform destroy
```

**注意**：销毁前请确保 ECR 中的镜像已备份或不再需要。

## 注意事项

1. ECR 仓库名称在区域内唯一
2. ECR 登录令牌有效期为 12 小时
3. EKS 节点通过 IAM Role 自动访问 ECR，无需配置 credentials
4. 镜像推送和拉取使用相同的 URL（ECR 不区分内外网地址）
5. 建议启用镜像扫描以检测安全漏洞
6. 定期清理未使用的镜像以控制存储成本

## 故障排查

### ECR 登录失败

```bash
# 检查 AWS CLI 配置
aws configure list

# 测试 ECR 认证
aws ecr get-login-password --region us-east-1

# 检查 IAM 权限
aws sts get-caller-identity
```

### 镜像推送失败

```bash
# 检查仓库是否存在
aws ecr describe-repositories \
  --repository-names $(terraform output -raw registry_repository_name) \
  --region us-east-1

# 检查磁盘空间
docker system df

# 清理未使用的镜像
docker system prune -a
```

### EKS 无法拉取镜像

```bash
# 检查节点 IAM Role 权限
kubectl describe node <node-name>

# 检查 Pod 事件
kubectl describe pod <pod-name>

# 验证 ECR 策略
aws ecr get-repository-policy \
  --repository-name $(terraform output -raw registry_repository_name) \
  --region us-east-1
```

## 相关文档

- [AWS ECR 文档](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
- [AWS EKS 文档](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECR 生命周期策略](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
