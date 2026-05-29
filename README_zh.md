# TapData One-Deploy

[English](README.md) | [中文](README_zh.md)

TapData One-Deploy 是 TapData 官方全场景自动化部署工具，覆盖从单机开发测试到企业级云原生生产的完整交付链路。

> *Build Once, Run Anywhere — 一次构建，全场景运行*

| 模式 | 场景 | 技术栈 | 当前进度 |
|------|------|--------|------|
| **Lite** | 开发测试 / POC | Docker Compose | ✅    |
| **Cloud** | 华为云 CCE | Terraform + Helm | ✅    |
| **Cloud** | AWS EKS | Terraform + Helm | ⌛️   |
| **On-Prem** | 客户机房 / 离线环境 | 离线镜像包 + Helm | ⌛️    |

---

## 快速开始

```bash
# 下载
curl -L https://resource.tapdata.net/deploy/tap-deploy -o tap-deploy && chmod +x tap-deploy

# 初始化 → 预览 → 部署
./tap-deploy init      # 交互式配置向导
./tap-deploy plan      # 预览部署内容
./tap-deploy apply     # 执行部署
```

Lite 模式部署完成后，浏览器访问 `http://localhost:13030` 即可进入控制台（默认账号 `admin@admin.com`，密码 `admin`）。

更多命令：

| 命令 | 说明 |
|------|------|
| `./tap-deploy init` | 交互式配置向导，生成所有配置文件 |
| `./tap-deploy plan` | 预览部署内容（不执行） |
| `./tap-deploy apply` | 执行部署 |
| `./tap-deploy status` | 查看部署状态 |
| `./tap-deploy destroy` | 卸载并清理 |
| `./tap-deploy bundle` | 制作离线镜像包（On-Prem） |
| `./tap-deploy -d /path init` | 指定工作目录 |

---

## 工作流程

`tap-deploy` 采用 **模板渲染** 机制管理配置：

1. `init` 阶段：交互式收集参数 → 保存至 `.tap-deploy.env` → 从模板渲染生成最终配置文件
2. `apply` 阶段：读取配置 → 执行部署（Docker Compose / Terraform + Helm / Helm）

```
init 交互式向导
  ├─ 参数 → .tap-deploy.env（配置存储）
  ├─ 模板 + .tap-deploy.env → docker-compose.yaml / values.yaml / application.yml / terraform.tfvars
  └─ Terraform init（Cloud 模式）

apply 部署执行
  ├─ Lite:    docker compose up -d
  ├─ Cloud:   terraform apply → 推送镜像 → helm install
  └─ On-Prem: helm install（可选离线镜像加载）
```

---

## 配置管理

### 配置文件说明

| 文件 | 生成时机 | 说明 |
|------|---------|------|
| `.tap-deploy.env` | `init` | 核心配置存储，所有参数的来源 |
| `application.yml` | `init` | TapData 应用配置（MongoDB 连接、Java 参数等） |
| `agent.yml` | `init` | Agent 标识配置 |
| `docker-compose.yaml` | `init`（Lite） | Docker Compose 编排文件 |
| `values.yaml` | `init`（Cloud/On-Prem） | Helm 部署参数 |
| `terraform.tfvars` | `init`（Cloud） | Terraform 基础设施变量 |

### 自定义配置

**方式一：重新运行 `init` 向导**

修改任何参数的最简方式，向导会覆盖重新生成所有配置文件。

**方式二：直接编辑 `.tap-deploy.env`**

手动修改配置后，需重新渲染模板或直接编辑对应的生成文件。适合批量调整或自动化场景。

**方式三：直接编辑生成文件**

`init` 生成的 `docker-compose.yaml`、`values.yaml`、`application.yml` 等均为标准格式文件，可直接编辑进行深度定制。适用于 `init` 向导未覆盖的高级参数（如资源配额、Ingress 注解、MongoDB 存储引擎参数等）。

> **注意**：再次运行 `init` 会覆盖已生成的配置文件，手动修改会丢失。建议将定制内容记录在 `.tap-deploy.env` 或通过 Helm values 覆盖文件管理。

---

## Lite 模式

单机部署，5 分钟快速启动，适合开发测试和 POC。

**前置条件**：Docker 20.10+ 及 Docker Compose 插件，当前用户有 Docker 执行权限，可访问公网。

### init 向导参数

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| TapData 版本 | `TAP_DEPLOY_IMAGE_TAG` | `latest` | 从 Docker Hub 拉取的镜像 Tag |
| MongoDB 端口 | `MONGO_HOST_PORT` | `27006` | MongoDB 宿主机端口映射 |
| TapData 端口 | `TAPDATA_HOST_PORT` | `13030` | TapData 宿主机端口映射 |
| MongoDB 用户名 | `TAP_DEPLOY_MONGO_USER` | `root` | - |
| MongoDB 密码 | `TAP_DEPLOY_MONGO_PASSWORD` | `AbcDef123` | - |

### 隐含配置项

以下配置在 `.tap-deploy.env` 中定义，`init` 向导未直接询问，可手动编辑调整：

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| `TAP_DEPLOY_TZ` | `Asia/Shanghai` | 容器时区 |
| `TAP_DEPLOY_JAVA_VERSION` | `java17` | JDK 版本（java8 / java11 / java17） |
| `TAP_DEPLOY_LICENSE_HOST` | - | License 服务器地址 |

### 深度定制

直接编辑 `docker-compose.yaml` 可调整：
- 容器资源限制（默认 CPU 4 核 / 内存 12G）
- 卷挂载路径
- 健康检查策略
- 环境变量（`FRONTEND_WORKER_COUNT`、`API_WORKER_COUNT` 等）

---

## Cloud 模式

自动化云基础设施创建 + Kubernetes 部署，适合生产~环境。

**前置条件**：Terraform 1.7+、Helm 3.14+、kubectl、Docker，云厂商 AK/SK 权限。

### 部署流程

```
terraform apply → 创建 VPC / CCE(EKS) / SWR(ECR) / NAT
       ↓
推送镜像到云镜像仓库（SWR / ECR）
       ↓
安装 MongoDB Community Operator
       ↓
helm install → 部署 TapData（MongoDB + server + engine + apiserver）
```

### init 向导参数

**通用参数**

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| TapData 版本 | `TAP_DEPLOY_IMAGE_TAG` | `latest` | 镜像 Tag |
| 云厂商 | `TAP_DEPLOY_CLOUD_PROVIDER` | - | `huaweicloud` / `aws` |
| Access Key | `TAP_DEPLOY_CLOUD_ACCESS_KEY` | - | 密码输入，不回显 |
| Secret Key | `TAP_DEPLOY_CLOUD_SECRET_KEY` | - | 密码输入，不回显 |
| Region | `TAP_DEPLOY_CLOUD_REGION` | `ap-southeast-1` | - |
| 可用区 | `TAP_DEPLOY_CLOUD_AZS` | `ap-southeast-1a,ap-southeast-1b` | 逗号分隔 |
| 集群名称 | `TAP_DEPLOY_CLOUD_CLUSTER_NAME` | `tapdata` | K8s 集群名称 |
| 节点数 | `TAP_DEPLOY_CLOUD_NODE_COUNT` | `3` | Worker 节点数量 |
| MongoDB 用户名 | `TAP_DEPLOY_MONGO_USER` | `root` | - |
| MongoDB 密码 | `TAP_DEPLOY_MONGO_PASSWORD` | `AbcDef123` | - |
| Helm Release | `TAP_DEPLOY_HELM_RELEASE` | `tapdata` | - |
| 命名空间 | `TAP_DEPLOY_NAMESPACE` | `tapdata` | - |

**华为云特有**

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| 节点规格 | `TAP_DEPLOY_CLOUD_NODE_FLAVOR` | `s2.4xlarge.2` | [规格参考](https://support.huaweicloud.com/intl/zh-cn/usermanual-cce/cce_10_0719.html) |

**AWS 特有**

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| 节点实例类型 | `TAP_DEPLOY_CLOUD_NODE_INSTANCE_TYPE` | `t3.medium` | - |
| K8s 版本 | `TAP_DEPLOY_CLOUD_CLUSTER_VERSION` | `1.29` | - |

### 镜像仓库自动配置

Cloud 模式下，镜像仓库信息在 `terraform apply` 后自动获取，**无需手动配置**：

- 华为云：SWR 内网拉取地址 + 外网推送地址 + 临时 AK/SK 鉴权
- AWS：ECR 内网拉取地址 + 外网推送地址 + ECR 鉴权

自动写入 `.tap-deploy.env` 并在 `apply` 阶段渲染到 `values.yaml`。

### Ingress 配置

各云厂商使用独立的 Ingress 配置文件，`apply` 时自动合并：

| 云厂商 | 文件 | 负载均衡 |
|--------|------|----------|
| 华为云 | `values-ingress-huaweicloud.yaml` | ELB（自动创建公网 ELB） |
| AWS | `values-ingress-aws.yaml` | ALB（Internet-facing） |

如需自定义 Ingress（域名、TLS 证书、带宽等），编辑对应的 `values-ingress-*.yaml` 文件。

### 深度定制

直接编辑 `values.yaml` 可调整：
- 副本数（`tapdata-server.replicaCount` 等，默认各 2）
- 资源配额（CPU/内存 limits & requests）
- MongoDB 副本集成员数、存储类、存储大小
- Service 类型（ClusterIP / NodePort）
- API Server 启用/禁用

编辑 `terraform.tfvars` 可调整：
- VPC CIDR
- 密钥对名称
- 镜像仓库组织/仓库名

### 获取访问地址

```bash
# 华为云
kubectl describe ingress -n tapdata -l app.kubernetes.io/name=tapdata | grep 'kubernetes.io/elb.ip'

# AWS
kubectl get ingress -n tapdata
```

---

## (⌛️)On-Prem 模式

面向客户机房和离线环境，基于已有 Kubernetes 集群部署。

**前置条件**：Helm 3.14+、kubectl，可访问 K8s 集群。离线模式需 Docker 及预先制作的镜像包。

### 在线部署

K8s 集群可访问公网（或私有镜像仓库）时：

```bash
./tap-deploy init    # 选择 On-Prem → 非离线环境
./tap-deploy apply
```

### 离线部署

**联网环境制作镜像包：**

```bash
./tap-deploy bundle --output images-bundle.tar.gz
```

**离线环境部署：**

```bash
# 加载镜像
docker load -i images-bundle.tar.gz

# 推送到内部镜像仓库
docker tag tapdata8/tapdata:latest <harbor>/tapdata:latest
docker push <harbor>/tapdata:latest

# 部署
./tap-deploy init    # 选择 On-Prem → 离线环境，填写内部镜像仓库地址
./tap-deploy apply
```

### init 向导参数

| 参数 | 环境变量 | 默认值 | 说明 |
|------|---------|--------|------|
| TapData 版本 | `TAP_DEPLOY_IMAGE_TAG` | `latest` | 镜像 Tag |
| 是否离线 | `TAP_DEPLOY_OFFLINE` | `false` | 离线环境选 `true` |
| MongoDB 用户名 | `TAP_DEPLOY_MONGO_USER` | `root` | - |
| MongoDB 密码 | `TAP_DEPLOY_MONGO_PASSWORD` | `AbcDef123` | - |
| Helm Release | `TAP_DEPLOY_HELM_RELEASE` | `tapdata` | - |
| 命名空间 | `TAP_DEPLOY_NAMESPACE` | `tapdata` | - |
| 内部镜像仓库 | `TAP_DEPLOY_HARBOR_REGISTRY` | - | 离线模式必填 |
| 镜像仓库前缀 | `TAP_DEPLOY_IMAGE_REGISTRY` | - | 在线模式填写，留空则用 Docker Hub |

### 深度定制

与 Cloud 模式相同，直接编辑 `values.yaml` 调整副本数、资源配额、MongoDB 参数等。

---

## 生产环境建议

### 资源规划

| 组件 | 副本数 | CPU | 内存 |
|------|--------|-----|------|
| tapdata-server | 2 | 500m ~ 2 | 2Gi ~ 4Gi |
| tapdata-engine | 2 | 500m ~ 2 | 2Gi ~ 4Gi |
| tapdata-apiserver | 2 | 250m ~ 1 | 1Gi ~ 2Gi |
| MongoDB | 3 节点副本集 | - | - |

### 存储

- 华为云：超高 IO EVS（SSD）
- AWS：gp3 / io2 EBS
- 自建：建议 SSD，降低 CDC 延迟

### 高可用

- MongoDB 三节点副本集，自动故障转移
- 应用多副本 + 负载均衡
- 滚动更新零停机，30s 优雅停机

---

## 故障排查

| 现象 | 排查方法 |
|------|---------|
| Pod 启动失败 | `kubectl -n tapdata describe pod <pod-name>` |
| 服务不可达 | 检查 Ingress / ELB / 安全组 |
| MongoDB 连接失败 | `kubectl get mdbc -n tapdata` |
| License 过期 | 检查 `$TAPDATA_WORK_DIR/license.txt` |

---

## 技术栈

Docker 20.10+ · Kubernetes 1.24+ · Helm 3.14+ · Terraform 1.7+ · MongoDB 6.0+ · AMD64 / ARM64

---

## 注意事项

- `init` 需要下载配置模板，`apply` 需要拉取镜像；离线环境请提前准备镜像包
- 生产环境使用超高 IO 存储以降低 CDC 延迟
- 所有 Connector 均经过 ARM 编译验证
- macOS 需确保终端有磁盘访问权限
- 默认提供 30 天免费试用 License，联系 TapData 团队获取延长

---

[GitHub](https://github.com/tapdata/tapdata-deploy) · [Issues](https://github.com/tapdata/tapdata-deploy/issues)
