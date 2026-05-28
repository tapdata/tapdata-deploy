# TapData One-Deploy

[English](README.md) | [中文](README_zh.md)

## 项目简介

TapData One-Deploy 是 TapData 官方提供的全场景自动化部署工具，实现从单机测试到企业级云原生环境的一键式交付。

**核心愿景**：*"一次构建，全场景运行 (Build Once, Run Anywhere)"*

### 部署模式

| 模式 | 场景 | 技术栈 |
|------|------|--------|
| **Lite** | 本地开发测试、快速 POC | Docker Compose |
| **Cloud** | 华为云/AWS 生产环境 | Terraform + Kubernetes |
| **On-Prem** | 客户机房、离线断网环境 | 离线镜像包 + Harbor |

---

## 核心特性

- **零安装**：直接下载运行，支持 Linux/macOS
- **交互式配置**：命令行向导自动生成配置
- **全场景覆盖**：Lite / Cloud / On-Prem 三种模式
- **多架构支持**：AMD64 和 ARM64（华为鲲鹏/飞腾）

---

## 快速开始

### 下载与运行

```bash
# 下载 tap-deploy 脚本
curl -L https://resource.tapdata.net/deploy/tap-deploy -o tap-deploy
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

### 卸载

```bash
./tap-deploy destroy
```

---

## 命令参考

| 命令 | 说明 |
|------|------|
| `./tap-deploy init` | 初始化配置，交互式向导生成配置文件 |
| `./tap-deploy plan` | 预览部署内容，不执行真实部署 |
| `./tap-deploy apply` | 执行部署 |
| `./tap-deploy status` | 查看部署状态 |
| `./tap-deploy destroy` | 卸载部署 |
| `./tap-deploy bundle` | 制作离线安装包（On-Prem 场景） |

---

## 部署模式

### Lite 模式

**适用场景**：本地开发、快速测试、Demo 演示

**特点**：单节点 MongoDB + TapData，Docker Compose 编排，5 分钟快速启动

### Cloud 模式

**适用场景**：华为云 CCE、AWS EKS 等云厂商生产环境

**特点**：
- 自动创建云基础设施（VPC、K8s 集群、ELB/ALB、NAT 网关）
- MongoDB 三节点副本集，自动挂载云硬盘
- TapData 多副本部署，支持高可用

**华为云 CCE 示例**：
```bash
# 1. 初始化配置（选择 Cloud 模式 → 华为云，填写 AK/SK、Region 等）
./tap-deploy init

# 2. 执行部署（自动完成 Terraform + Helm）
./tap-deploy apply

# 3. 获取访问地址
kubectl -n tapdata describe ingress tapdata-ingress | grep "kubernetes.io/elb.ip"
```

### On-Prem 模式

**适用场景**：客户机房、断网环境、内部 Harbor 仓库

**特点**：支持离线镜像包制作，自动完成镜像加载、打标、推送

**完整流程**：
```bash
# 联网环境：制作离线包
./tap-deploy bundle --output images-bundle.tar.gz

# 传输到离线环境
scp images-bundle.tar.gz user@target-host:/opt/

# 离线环境：部署（选择 On-Prem 模式，填写内部 Harbor 地址）
./tap-deploy init
./tap-deploy apply
```

---

## 生产环境建议

### 资源配置

**生产环境**：tapdata-server/engine/apiserver 各 2 副本，MongoDB 三节点副本集

**存储建议**：
- 华为云：SSD（超高 IO EVS）
- AWS：gp3 / io2 EBS

### 高可用

- 数据库：三节点副本集
- 应用组件：多副本 + 负载均衡
- 滚动更新：零停机升级，支持 30s 优雅停机

---

## 运维管理

### 升级

```bash
./tap-deploy apply --version <new-version>
```

支持滚动更新，零停机升级。

### 故障排查

| 问题 | 排查方法 |
|------|---------||
| Pod 启动失败 | `kubectl -n tapdata describe pod <pod-name>` |
| 服务不可达 | 检查 Ingress、ELB/ALB、安全组 |
| MongoDB 连接失败 | `kubectl get mdb -n tapdata` |
| License 过期 | 检查 `$TAPDATA_WORK_DIR/license.txt` |

---

## 技术栈

- **容器**：Docker 20.10+, Docker Compose 2.0+
- **编排**：Kubernetes 1.24+, Helm 3.14+
- **基础设施**：Terraform 1.7+（华为云 CCE / AWS EKS）
- **数据库**：MongoDB 6.0+（Community Operator 管理副本集）
- **架构**：AMD64 / ARM64（Ubuntu 24.04 基础镜像）

---

## 注意事项

- **网络**：`init` 需要下载配置模板，`apply` 需要拉取镜像（On-Prem 需提前准备离线包）
- **存储**：生产环境使用超高 IO 存储以降低 CDC 延迟
- **ARM 兼容**：所有 Connector 均经过 ARM 编译验证
- **macOS**：确保终端有磁盘访问权限

---

## License 管理

容器启动时自动向 License Server 申请 License（HTTPS + 服务端鉴权）：
- `valid_days`：有效期（默认 30 天）
- `licenseType`：类型（OP = 私有化部署）
- `engineLimit`：引擎数量限制

K8s 模式可通过 ConfigMap 挂载预申请的 `license.txt`

---

## 更多信息

- **GitHub 仓库**：https://github.com/tapdata/tapdata-deploy
- **问题反馈**：请在 GitHub Issues 中提交
