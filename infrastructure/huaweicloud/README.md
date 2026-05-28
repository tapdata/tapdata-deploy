# Huawei Cloud Infrastructure (CCE)

使用 Terraform 在华为云上部署 TapData Kubernetes 集群（CCE）及配套基础设施。

## 前置条件

- Terraform >= 1.0
- 华为云账号及 Access Key / Secret Key
- 已配置华为云 CLI（可选）

## 快速开始

### 1. 配置变量

复制并编辑变量文件：

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

主要配置项：

```hcl
region             = "cn-north-4"
access_key         = "your-access-key"
secret_key         = "your-secret-key"
availability_zones = ["cn-north-4a", "cn-north-4b"]
cluster_name       = "tapdata-hw"
node_count         = 2
node_flavor        = "s6.large.2"

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

### 4. 获取集群信息

```bash
# 获取 kubeconfig
terraform output kubeconfig > kubeconfig.json

# 配置 kubectl
export KUBECONFIG=$(pwd)/kubeconfig.json
kubectl get nodes
```

## 镜像仓库（SWR）配置

### 输出变量说明

部署完成后，会输出以下镜像仓库相关信息：

```bash
# 查看组织名称
terraform output registry_organization

# 查看仓库名称
terraform output registry_repository_name

# 查看内网 pull 地址（CCE 节点使用）
terraform output registry_inner_pull_url

# 查看外网 push 地址
terraform output registry_external_push_url

# 查看登录命令
terraform output registry_login_command

# 查看完整认证信息
terraform output registry_auth_info
```

### Docker 登录 SWR

1. 获取临时认证令牌（通过华为云 CLI）：

```bash
# 安装华为云 CLI
# 参考：https://support.huaweicloud.com/usermanual-swr/swr_04_0011.html

# 获取临时登录令牌
swr login --region cn-north-4
```

或者使用 API 获取令牌后登录：

```bash
# 获取登录指令
terraform output registry_login_command

# 手动登录（替换 <temporary_token>）
docker login -u <your-access-key> -p <temporary_token> swr.cn-north-4.myhuaweicloud.com
```

### 推送镜像到 SWR

```bash
# 1. 构建镜像
docker build -t myapp:v1.0 .

# 2. 标记镜像（使用外网 push 地址）
REGISTRY_URL=$(terraform output -raw registry_external_push_url)
docker tag myapp:v1.0 ${REGISTRY_URL}:v1.0

# 3. 推送镜像
docker push ${REGISTRY_URL}:v1.0
```

### 在 CCE 中拉取镜像

CCE 节点会自动使用内网地址拉取镜像，无需额外配置。在 Kubernetes 部署文件中指定镜像地址：

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
        image: swr.cn-north-4.myhuaweicloud.com/your-org/your-repo:latest
        # CCE 节点通过内网自动拉取，无需 imagePullSecrets
```

## 基础设施组件

部署包含以下资源：

- **VPC**：虚拟私有云
- **子网**：多可用区子网
- **安全组**：开放 3030 端口（TapData）及 VPC 内网通信
- **CCE 集群**：Kubernetes 集群
- **节点池**：工作节点
- **NAT 网关**：节点访问互联网
- **EIP**：集群 API Server 公网访问
- **SWR**：容器镜像仓库（组织和仓库）

## 清理资源

```bash
terraform destroy
```

## 注意事项

1. SWR 组织名称在账号级别唯一
2. 内网 pull 地址仅适用于同一区域的 CCE 节点
3. 外网 push 地址需要配置 EIP 和 NAT 网关
4. 镜像仓库默认私有，需要认证才能访问
5. 建议配置镜像生命周期策略以管理存储成本

## 相关文档

- [华为云 SWR 文档](https://support.huaweicloud.com/swr/index.html)
- [华为云 CCE 文档](https://support.huaweicloud.com/cce/index.html)
- [Terraform HuaweiCloud Provider](https://registry.terraform.io/providers/huaweicloud/huaweicloud/latest/docs)
