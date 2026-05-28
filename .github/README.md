# GitHub Actions CI/CD Workflow

## 目标
在推送或合并代码到 main 分支时，自动执行以下操作：
1. 验证 Terraform 配置（AWS 和 Huawei Cloud）
2. 验证 Helm charts 配置
3. 验证 docker-compose.yml 配置
4. 打包最新代码并上传到阿里云 OSS

## 实施步骤

### Task 1: 创建 GitHub Actions workflow 文件
创建文件：`.github/workflows/ci-cd.yml`

Workflow 触发条件：
- push 到 main 分支
- pull_request 合并到 main 分支

### Task 2: Terraform 验证 Job
- 检出代码
- 安装 Terraform
- 验证 AWS Terraform 配置：
    - 进入 `infrastructure/aws/` 目录
    - 执行 `terraform init`
    - 执行 `terraform validate`
- 验证 Huawei Cloud Terraform 配置：
    - 进入 `infrastructure/huaweicloud/` 目录
    - 执行 `terraform init`
    - 执行 `terraform validate`

### Task 3: Helm 验证 Job
- 检出代码
- 安装 Helm
- 验证主 chart：
    - 进入 `deploy-on-kubernetes/` 目录
    - 执行 `helm lint .`
    - 执行 `helm template .` 验证渲染
- 验证子 charts：
    - 验证 `charts/mongodb/`
    - 验证 `charts/tapdata-server/`
    - 验证 `charts/tapdata-engine/`
    - 验证 `charts/tapdata-apiserver/`

### Task 4: Docker Compose 验证 Job
- 检出代码
- 安装 Docker Compose
- 验证配置：
    - 进入 `deploy-on-docker/` 目录
    - 执行 `docker compose config` 验证语法
    - 执行 `docker compose config --quiet` 静默验证

### Task 5: 打包上传到 OSS Job
- 检出代码
- 配置阿里云 OSS 凭据（从 GitHub Secrets 读取）
    - `OSS_ACCESS_KEY_ID`
    - `OSS_ACCESS_KEY_SECRET`
    - `OSS_BUCKET_NAME`
    - `OSS_ENDPOINT`
- 安装 ossutil 工具
- 打包代码：
    - 使用 tar.gz 格式打包整个项目
- 上传到 OSS：
    - 上传到指定 bucket
    - 文件名固定为 `tapdata-deploy-latest.tar.gz`，存在时直接覆盖替换

### Task 6: 配置 GitHub Secrets 说明
需要配置的 Secrets：
- `OSS_ACCESS_KEY_ID`: 阿里云 AccessKey ID
- `OSS_ACCESS_KEY_SECRET`: 阿里云 AccessKey Secret
- `OSS_BUCKET_NAME`: OSS bucket 名称
- `OSS_ENDPOINT`: OSS endpoint（如 oss-cn-hangzhou.aliyuncs.com）

## 关键技术点
- 使用 GitHub Actions 矩阵策略并行执行验证任务
- Terraform 验证使用 `-check=assertions` 选项
- Helm 验证使用 `--debug` 输出详细信息
- OSS 上传使用官方 ossutil 工具
- 所有 job 失败时提供详细的错误日志

## 文件结构
```
.github/
  workflows/
    ci-cd.yml          # 主 workflow 文件
```
