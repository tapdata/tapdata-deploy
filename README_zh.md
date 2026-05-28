# TapData One-Deploy

[English](README.md) | [中文](README_zh.md)

## 项目简介

TapData One-Deploy 是 TapData 官方提供的全场景自动化部署工具。通过一个统一的命令行工具，实现从单机测试到企业级云原生环境的一键式交付。

**核心愿景**：*"一次构建，全场景运行 (Build Once, Run Anywhere)"*

通过顶层 CLI 将 Terraform（基础设施编排）、Helm（应用部署）、Docker Compose（本地开发）封装为统一接口，屏蔽底层环境差异，提供标准化的 TapData 部署流程。

### 适用场景

| 场景 | 部署模式 | 典型用户 |
|------|---------|---------|
| 本地开发测试、快速 POC | Lite (Docker Compose) | 开发者、售前工程师 |
| 华为云/AWS 生产环境 | Cloud (Terraform + K8s) | 运维工程师、云架构师 |
| 客户机房、离线断网环境 | On-Prem (离线镜像包) | 私有化部署实施团队 |

---

## 核心特性

- **零安装**：无需预先安装任何工具，直接从互联网下载 `tap-deploy` 脚本即可运行（支持 Linux/macOS）
- **交互式配置**：命令行向导自动收集环境参数，生成部署配置并完成部署
- **全场景覆盖**：
  - **Lite 模式**：Docker Compose，5 分钟极速拉起（TapData + MongoDB）
  - **Cloud 模式**：自动创建云基础设施（VPC、K8s 集群、负载均衡），适配华为云 CCE、AWS EKS
  - **On-Prem 模式**：离线镜像包制作与部署，支持断网环境与客户内部 Harbor 仓库
- **多架构支持**：原生支持 AMD64 和 ARM64（包括华为鲲鹏/飞腾），所有 Connector 均经过 ARM 编译验证
- **安全可信**：License 自动申请（HTTPS + 服务端鉴权），敏感信息不暴露在配置文件中

---

## 架构设计

### 分层架构

```
┌─────────────────────────────────────────────────────┐
│                    CLI 命令层                        │
│  init / plan / apply / bundle / status / destroy    │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                   生成器层（模板渲染）                  │
│  根据部署模式组合模板，渲染输出部署产物                    │
└────────┬───────────┬───────────┬───────────┬────────┘
         │           │           │           │
┌────────▼───┐ ┌─────▼────┐ ┌───▼────┐ ┌───▼────────┐
│common 模板  │ │Docker    │ │Helm    │ │Terraform   │
│application │ │模板       │ │模板     │ │模板         │
│agent.yml   │ │docker-   │ │values. │ │providers.tf│
│license.txt │ │compose   │ │yaml    │ │variables.tf│
└────────────┘ └──────────┘ └────────┘ │main.tf     │
                                       └────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                   执行器层                            │
│  封装 Docker / Helm / Terraform 调用，统一输出与错误处理 │
└─────────────────────────────────────────────────────┘
```

### 组件依赖关系

TapData 由以下核心组件构成：

```
┌──────────────────────────────────────────────────────┐
│                    Ingress / ELB                      │
│                 （外部访问入口）                        │
└──────────────┬───────────────────────┬───────────────┘
               ↓                       ↓
  ┌────────────────────────┐  ┌────────────────────────┐
  │    tapdata-server      │  │   tapdata-apiserver     │
  │    (TM 管理端)          │  │   (API 服务)            │
  │    Port: 3030           │  │   Port: 3080            │
  └────────────┬───────────┘  └──┬──────────────┬───────┘
   ↑           ↓                  │              ↓
   │   ┌───────────────┐         │      ┌──────────────┐
   │   │    MongoDB     │←────────┘      │   Other DB   │
   │   │  (元数据存储)   │                │              │
   │   │  Port: 27017   │                └──────────────┘
   │   └───────────────┘
   │            
  ┌┴───────────────────────┐
  │    tapdata-engine      │
  │    (执行引擎)           │
  │    Port: 3035/3036     │
  └────────────────────────┘
```

### 启动顺序

K8s 环境下，组件按以下顺序依次启动（通过 Init Container 实现依赖等待）：

```
MongoDB (Operator 创建 ReplicaSet)
  → tapdata-server (Init: 等待 MongoDB:27017 就绪)
    → tapdata-engine (Init: 等待 tapdata-server-svr:3030 就绪)
    → tapdata-apiserver (Init: 等待 tapdata-server-svr:3030 就绪)
```

Lite（Docker Compose）模式通过 `depends_on` + `healthcheck` 实现类似效果。

---

## 快速开始

### 下载与运行

```bash
# 下载 tap-deploy 脚本
curl -L https://github.com/tapdata/tapdata-deploy/releases/latest/download/tap-deploy -o tap-deploy
chmod +x tap-deploy

# 查看帮助
./tap-deploy --help
```

### Lite 模式：5 分钟快速体验

适合本地开发测试，无需配置云环境：

```bash
# 1. 初始化配置（选择 Lite 模式，设置管理员密码）
./tap-deploy init

# 2. 预览部署内容
./tap-deploy plan

# 3. 执行部署
./tap-deploy apply

# 4. 访问 TapData 控制台
# 浏览器打开: http://localhost:3030
# 用户名: admin
# 密码: <你在 init 时设置的密码>
```

### 查看部署状态

```bash
./tap-deploy status
```

### 卸载部署

```bash
./tap-deploy destroy
```

---

## 部署模式详解

### Lite 模式（Docker Compose）

**适用场景**：本地开发、快速测试、Demo 演示

**核心特点**：
- 单节点 MongoDB + 单节点 TapData
- 使用 Docker Compose 编排
- Host 网络模式，端口直接映射到宿主机
- 默认 3030 端口访问控制台

**产物**：
- `docker-compose.yaml`
- `.tap-deploy.env`（环境变量）

**底层执行**：
```bash
docker compose -f docker-compose.yaml up -d
```

### Cloud 模式（Terraform + Kubernetes）

**适用场景**：华为云 CCE、AWS EKS 等云厂商生产环境

**核心特点**：
- 自动创建云基础设施（VPC、K8s 集群、ELB/ALB、NAT 网关）
- MongoDB 三节点副本集，自动挂载云硬盘（EVS/EBS）
- TapData 组件多副本部署，支持高可用
- 自动配置 Ingress 和公网访问

**产物**：
- Terraform 配置：`main.tf`、`terraform.tfvars`
- Helm 配置：`values.yaml`

**底层执行**：
```bash
# 1. Terraform 创建基础设施
terraform init
terraform apply -var-file=terraform.tfvars

# 2. 安装 MongoDB Community Operator
helm install community-operator mongodb/community-operator \
  --namespace mongodb --create-namespace

# 3. 部署 TapData
helm install tapdata ./deploy-on-kubernetes \
  --namespace tapdata --create-namespace \
  -f values.yaml
```

**华为云 CCE 示例流程**：
```bash
# 1. 初始化 Cloud 模式配置
./tap-deploy init
# 选择 Cloud 模式 → 华为云
# 填写 AK/SK、Region、可用区、集群规格等

# 2. 执行部署（自动完成 Terraform + Helm）
./tap-deploy apply

# 3. 获取访问地址
kubectl -n tapdata describe ingress tapdata-ingress | grep "kubernetes.io/elb.ip"
```

### On-Prem 模式（离线部署）

**适用场景**：客户机房、断网环境、内部 Harbor 仓库

**核心特点**：
- 支持制作离线镜像包
- 自动完成镜像加载、打标、推送到内部仓库
- 通过修改 `values.yaml` 镜像前缀对接现有 K8s 集群

**完整流程**：

```bash
# ===== 联网环境：制作离线包 =====
./tap-deploy bundle --output images-bundle.tar.gz

# ===== 传输到离线环境 =====
scp images-bundle.tar.gz user@target-host:/opt/

# ===== 离线环境：部署 =====
# 1. 初始化配置（选择 On-Prem 模式，填写内部 Harbor 地址）
./tap-deploy init

# 2. 执行部署（自动完成镜像加载、打标、推送、Helm 安装）
./tap-deploy apply
```

**底层执行**：
```bash
# 加载镜像
docker load -i images-bundle.tar.gz

# 打标并推送到内部仓库
docker tapdata8/tapdata <harbor-registry>/tapdata/tapdata:<version>
docker push <harbor-registry>/tapdata/tapdata:<version>

# Helm 部署
helm install tapdata ./deploy-on-kubernetes \
  --namespace tapdata --create-namespace \
  -f values.yaml
```

---

## 命令参考

| 命令 | 说明 |
|------|------|
| `./tap-deploy init` | 初始化配置，交互式向导生成部署配置文件 |
| `./tap-deploy plan` | 预览部署组件及内容，不执行真实部署 |
| `./tap-deploy apply` | 根据配置执行部署 |
| `./tap-deploy status` | 查看当前部署状态 |
| `./tap-deploy destroy` | 卸载部署 |
| `./tap-deploy bundle` | 制作离线安装包（On-Prem 场景） |

### init — 初始化配置

```bash
./tap-deploy init
```

**交互过程**：
1. 选择模式：Lite | Cloud | On-Prem
2. 通用参数：Admin Password、MongoDB URI、Storage Path
3. Cloud/On-Prem 特有：Helm Release Name、Namespace、镜像仓库前缀
4. Cloud 特有：Access Key/Secret Key、Region、可用区、集群规格（新建或复用）

**生成的配置文件**：
- 应用配置：`application.yml`、`agent.yml`、`license.txt`（可选）
- 部署配置：
  - Lite：`docker-compose.yaml`
  - Cloud：`main.tf`、`terraform.tfvars`、`values.yaml`
  - On-Prem：`values.yaml`

### plan — 预览部署

```bash
./tap-deploy plan
```

**输出示例**：
```
部署模式: Lite
├── MongoDB (mongo:6.0)
│   └── 单节点副本集, 端口 27017
└── TapData (tapdata8/tapdata:latest)
    └── 全量模式, 端口 3030
```

### apply — 执行部署

```bash
./tap-deploy apply
```

各模式底层操作：

| 模式 | 底层执行操作 |
|------|-------------|
| Lite | `docker compose -f docker-compose.yaml up -d` |
| Cloud | `terraform apply` → 配置 Kubeconfig → `helm install` |
| On-Prem | `docker load` → `docker tag` → `docker push` → `helm install` |

### status — 查看状态

```bash
./tap-deploy status
```

各模式底层操作：

| 模式 | 底层执行操作 |
|------|-------------|
| Lite | `docker compose ps` |
| Cloud | `terraform show` + `helm status <release>` |
| On-Prem | `helm status <release>` |

### destroy — 卸载部署

```bash
./tap-deploy destroy
```

各模式底层操作：

| 模式 | 底层执行操作 |
|------|-------------|
| Lite | `docker compose -f docker-compose.yaml down -v` |
| Cloud | `helm uninstall` → `terraform destroy` |
| On-Prem | `helm uninstall` |

### bundle — 制作离线安装包

```bash
./tap-deploy bundle --output images-bundle.tar.gz
```

**打包内容**：
- TapData 应用镜像（AMD64 / ARM64）
- MongoDB 镜像
- MongoDB Community Operator 镜像
- 其他依赖镜像

---

## 配置管理

### 应用配置

TapData 应用配置通过 `application.yml` 和 `agent.yml` 管理，**严禁硬编码到镜像中**。

#### application.yml

核心配置项：

```yaml
spring:
  data:
    mongodb:
      uri: ""                          # MongoDB 连接串（模板渲染注入）
      username: ""                     # 用户名
      password: ""                     # 密码
      authenticationDatabase: admin

tapdata:
  mode: cluster                        # 运行模式
  conf:
    tapdataPort: '3030'
    backendUrl: ''                     # 后端 API 地址
    apiServerPort: '3080'
    tapdataJavaOpts: '-Xmx8G -Xms4G'  # Engine JVM 参数
    tapdataTMJavaOpts: '-Xmx8G -Xms4G' # TM JVM 参数
```

#### agent.yml

引擎 Agent 标识配置：

```yaml
{agentId: <unique-uuid>}              # 部署时自动生成
```

### 环境变量

容器通过环境变量控制运行时行为：

| 环境变量 | 说明 | 默认值 | 适用组件 |
|---------|------|--------|---------|
| `MONGODB_CONNECTION_STRING` | MongoDB 连接串 | 必填 | 所有 |
| `MONGODB_USER` | MongoDB 用户名 | - | 所有 |
| `MONGODB_PASSWORD` | MongoDB 密码 | - | 所有 |
| `BACKENDURL` | 后端 API 地址 | - | engine/apiserver |
| `MODULE` | 运行模块 | -（全量启动） | 所有 |
| `JAVA_VERSION` | JDK 版本 | java17 | 所有 |
| `TZ` | 时区 | Asia/Shanghai | 所有 |
| `LICENSE_HOST` | License 服务器地址 | - | 所有 |
| `TAPDATA_WORK_DIR` | 工作目录 | /tapdata/apps | 所有 |

**MODULE 环境变量说明**：

| 值 | 组件 | 说明 |
|----|------|------|
| `frontend` | tapdata-server | 启动 TM 前端 + 后端 |
| `backend` | tapdata-engine | 启动同步引擎 |
| `apiserver` | tapdata-apiserver | 启动 API 服务 |
| 不设置 | Lite 模式 | 全量启动所有模块 |

### 敏感信息管理

- **Docker Compose 模式**：敏感信息通过环境变量传入，不落盘到配置文件
- **K8s 模式**：
  - MongoDB 密码：通过 Secret 管理
  - 镜像仓库认证：通过 `imagePullSecret` 或 `registry-auth` Secret
  - License：通过 ConfigMap 挂载
  - TLS 证书：通过 Ingress TLS 配置引用 K8s TLS Secret
- **Terraform**：云厂商 AK/SK、Kubeconfig、SSH 私钥等标记为 `sensitive`，不会在日志中明文输出

---

## 生产环境指南

### 资源规划建议

#### 生产环境最低配置

| 组件 | 副本数 | CPU 请求/限制 | 内存 请求/限制 | 存储 |
|------|--------|-------------|-------------|------|
| tapdata-server | 2 | 500m/2 | 2Gi/4Gi | - |
| tapdata-engine | 2 | 500m/2 | 2Gi/4Gi | - |
| tapdata-apiserver | 2 | 250m/1 | 1Gi/2Gi | - |
| MongoDB | 3 节点副本集 | 1/2 | 2Gi/4Gi | 数据 10Gi + 日志 2Gi |

#### 测试环境最低配置

| 组件 | 副本数 | CPU 请求/限制 | 内存 请求/限制 | 存储 |
|------|--------|-------------|-------------|------|
| tapdata-server | 1 | 250m/1 | 1Gi/2Gi | - |
| tapdata-engine | 1 | 250m/1 | 1Gi/2Gi | - |
| tapdata-apiserver | 1 | 250m/500m | 512Mi/1Gi | - |
| MongoDB | 1 节点 | 500m/1 | 1Gi/2Gi | 数据 5Gi + 日志 1Gi |

### 存储类型建议

| 云厂商 | 推荐存储类型 | 说明 |
|--------|------------|------|
| 华为云 | SSD（超高 IO EVS） | 生产环境务必选择超高 IO，降低 CDC 延迟 |
| AWS | gp3 / io2 EBS | 根据吞吐需求选择 |

### 高可用配置

- **数据库**：部署为三节点副本集
- **TM 高可用**：
  - 默认部署为两副本，可修改 Deployment 副本数量
  - 请求基于 Load Balancer Service 实现负载均衡
- **引擎高可用**：
  - 默认部署为两副本，可修改 Deployment 副本数量
  - TM 负责执行任务的重新调度
- **负载均衡**：
  - 华为云：ELB + Nginx Ingress
  - AWS：ALB + Nginx Ingress

---

## 运维管理

### 升级策略

```bash
./tap-deploy apply --version <new-version>
```

各模式底层操作：

| 模式 | 底层执行操作 |
|------|-------------|
| Lite | `docker compose pull` → `docker compose up -d` |
| Cloud/On-Prem | `helm upgrade tapdata ./deploy-on-kubernetes -n tapdata -f values.yaml --set *.image.tag=<new-version>` |

**滚动更新**：K8s Deployment 默认采用 RollingUpdate 策略，确保升级过程中服务不中断。引擎组件内置 SIGTERM 监听，支持 30s 优雅停机以完成当前 Offset 提交后安全退出。

### 日志管理

- **应用日志**：
  - 容器内路径：`/tapdata/apps/logs/`
  - 应用程序自动进行日志压缩与过期删除
  - K8s 模式下默认使用 `emptyDir`，用户可配置 PVC 持久化
  - Lite 模式下挂载到宿主机 `./tapdata/logs/`
- **MongoDB 日志**：
  - 容器内路径：`/var/log/mongo/mongod.log`
  - Lite 模式下挂载到宿主机 `./mongodb/logs/`

### 故障排查

| 问题 | 排查方法 |
|------|---------|
| Pod 启动失败 | `kubectl -n tapdata describe pod <pod-name>` 查看 Events |
| 服务不可达 | 检查 Ingress 配置、ELB/ALB 状态、安全组规则 |
| MongoDB 连接失败 | 检查 ReplicaSet 状态：`kubectl get mdb -n tapdata` |
| 引擎任务不执行 | 检查 Engine Pod 日志：`kubectl -n tapdata logs <engine-pod>` |
| 镜像拉取失败 | 检查 imagePullSecret 配置与镜像仓库地址 |
| License 过期 | 检查 `$TAPDATA_WORK_DIR/license.txt` 有效期，重新申请 |

---

## 技术栈

### 核心工具链

| 工具 | 版本要求 | 用途 |
|------|---------|------|
| Docker | 20.10+ | 容器运行时（Lite 模式） |
| Docker Compose | 2.0+ | 容器编排（Lite 模式） |
| Kubernetes | 1.24+ | 容器编排平台（Cloud/On-Prem 模式） |
| Helm | 3.14+ | K8s 应用包管理 |
| Terraform | 1.7+ | 云基础设施编排（Cloud 模式） |

### 云平台支持

| 云平台 | 基础设施 | K8s 服务 | 存储 | 负载均衡 |
|--------|---------|---------|------|---------|
| 华为云 | VPC、EIP、NAT | CCE | EVS 云硬盘 | ELB |
| AWS | VPC、EIP、NAT | EKS | EBS | ALB |

### 数据库

- **MongoDB**：6.0+，使用 MongoDB Community Operator 管理副本集
- **副本集配置**：WiredTiger 引擎，oplogSizeMB: 1024，journalCompressor: zlib

### 镜像构建

- **基础镜像**：Ubuntu 24.04（AMD64）/ arm64v8/ubuntu:24.04（ARM64）
- **运行环境**：JDK 8/11/17、Node.js
- **多阶段构建**：基础镜像层 + 应用层，减少构建时间与存储空间

---

## 注意事项

- **网络访问**：`tap-deploy init` 需要网络访问以下载配置模板；`tap-deploy apply` 需要网络访问以拉取容器镜像。On-Prem 离线场景请提前准备好离线镜像包。
- **存储性能**：在 Cloud/On-Prem 模式下，生产环境务必选择"超高 IO" EVS 云硬盘（或本地 NVMe SSD）以降低 CDC 延迟。
- **信号处理**：Engine 组件镜像已内置 SIGTERM 监听，支持 30s 优雅停机以完成当前 Offset 提交后安全退出。
- **Ingress 兼容性**：默认采用厂商推荐 Ingress，并配置安全策略开放 TapData 控制台访问。
- **ARM 兼容性**：所有 Connector 在构建阶段均经过 ARM 编译扫描；如遇特定旧版 Connector 不支持 ARM，请联系官方获取适配版本。
- **macOS 兼容性**：在 macOS 上运行时，请确保已授予终端访问磁盘的权限。

---

## 许可证与支持

- **License 管理**：容器启动时自动向 License Server 申请 License（HTTPS + 服务端鉴权）
- **License 参数**：
  - `valid_days`：有效期（默认 30 天）
  - `licenseType`：类型（OP = 私有化部署）
  - `engineLimit`：引擎数量限制
- **手动指定**：K8s 模式下可通过 ConfigMap 挂载预申请的 `license.txt`

---

## 更多信息

- **详细设计文档**：[design.md](design.md)
- **GitHub 仓库**：https://github.com/tapdata/tapdata-deploy
- **问题反馈**：请在 GitHub Issues 中提交
