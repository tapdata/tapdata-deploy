# TapData One-Deploy

[English](README.md) | [中文](README_zh.md)

## Overview

TapData One-Deploy is the official automated deployment tool for TapData, providing unified delivery from single-node testing to enterprise-grade cloud-native environments through a single command-line interface.

**Core Vision**: *"Build Once, Run Anywhere"*

By abstracting Terraform (infrastructure orchestration), Helm (application deployment), and Docker Compose (local development) into a unified CLI interface, it shields underlying environment differences and provides a standardized TapData deployment workflow.

### Use Cases

| Scenario | Deployment Mode | Typical Users |
|----------|----------------|---------------|
| Local development, quick POC | Lite (Docker Compose) | Developers, Pre-sales Engineers |
| Huawei Cloud/AWS production | Cloud (Terraform + K8s) | DevOps Engineers, Cloud Architects |
| Customer data center, offline environment | On-Prem (Offline Image Bundle) | Private Deployment Teams |

---

## Key Features

- **Zero Installation**: No prerequisite tools needed. Simply download the `tap-deploy` script and run (supports Linux/macOS)
- **Interactive Configuration**: Command-line wizard automatically collects environment parameters, generates deployment configuration, and completes deployment
- **Full Scenario Coverage**:
  - **Lite Mode**: Docker Compose, 5-minute quick startup (TapData + MongoDB)
  - **Cloud Mode**: Automatic cloud infrastructure creation (VPC, K8s cluster, load balancer), compatible with Huawei Cloud CCE and AWS EKS
  - **On-Prem Mode**: Offline image bundle creation and deployment, supporting disconnected environments and internal Harbor registries
- **Multi-Architecture Support**: Native support for AMD64 and ARM64 (including Huawei Kunpeng/Phytium), all Connectors verified with ARM compilation
- **Security & Trust**: Automatic License application (HTTPS + server authentication), sensitive information never exposed in configuration files

---

## Architecture

### Layered Architecture

```
┌─────────────────────────────────────────────────────┐
│                    CLI Command Layer                  │
│  init / plan / apply / bundle / status / destroy    │
└────────────────────────┬────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                Generator Layer (Template Rendering)   │
│  Combine templates based on deployment mode,           │
│  render and output deployment artifacts                │
└────────┬───────────┬───────────┬───────────┬────────┘
         │           │           │           │
┌────────▼───┐ ┌─────▼────┐ ┌───▼────┐ ┌───▼────────┐
│Common      │ │Docker    │ │Helm    │ │Terraform   │
│Templates   │ │Template  │ │Template│ │Template    │
│application │ │docker-   │ │values. │ │providers.tf│
│agent.yml   │ │compose   │ │yaml    │ │variables.tf│
│license.txt │ └──────────┘ └────────┘ │main.tf     │
└────────────┘                         └────────────┘
                         │
┌────────────────────────▼────────────────────────────┐
│                   Executor Layer                      │
│  Encapsulate Docker/Helm/Terraform calls,              │
│  unified output and error handling                     │
└─────────────────────────────────────────────────────┘
```

### Component Dependencies

TapData consists of the following core components:

```
┌──────────────────────────────────────────────────────┐
│                    Ingress / ELB                      │
│                 (External Access Entry)                 │
└──────────────┬───────────────────────┬───────────────┘
               ↓                       ↓
  ┌────────────────────────┐  ┌────────────────────────┐
  │    tapdata-server      │  │   tapdata-apiserver     │
  │    (TM Management)      │  │   (API Service)         │
  │    Port: 3030           │  │   Port: 3080            │
  └────────────┬───────────┘  └──┬──────────────┬───────┘
   ↑           ↓                  │              ↓
   │   ┌───────────────┐         │      ┌──────────────┐
   │   │    MongoDB     │←────────┘      │   Other DB   │
   │   │  (Metadata)     │                │              │
   │   │  Port: 27017   │                └──────────────┘
   │   └───────────────┘
   │            
  ┌┴───────────────────────┐
  │    tapdata-engine      │
  │    (Execution Engine)   │
  │    Port: 3035/3036     │
  └────────────────────────┘
```

### Startup Sequence

In K8s environments, components start sequentially (dependency waiting via Init Containers):

```
MongoDB (Operator creates ReplicaSet)
  → tapdata-server (Init: Wait for MongoDB:27017 ready)
    → tapdata-engine (Init: Wait for tapdata-server-svr:3030 ready)
    → tapdata-apiserver (Init: Wait for tapdata-server-svr:3030 ready)
```

Lite (Docker Compose) mode achieves similar behavior through `depends_on` + `healthcheck`.

---

## Quick Start

### Download & Run

```bash
# Download tap-deploy script
curl -L https://github.com/tapdata/tapdata-deploy/releases/latest/download/tap-deploy -o tap-deploy
chmod +x tap-deploy

# View help
./tap-deploy --help
```

### Lite Mode: 5-Minute Quick Experience

Suitable for local development and testing, no cloud environment required:

```bash
# 1. Initialize configuration (select Lite mode, set admin password)
./tap-deploy init

# 2. Preview deployment
./tap-deploy plan

# 3. Execute deployment
./tap-deploy apply

# 4. Access TapData Console
# Open browser: http://localhost:3030
# Username: admin
# Password: <password you set during init>
```

### Check Deployment Status

```bash
./tap-deploy status
```

### Uninstall Deployment

```bash
./tap-deploy destroy
```

---

## Deployment Modes

### Lite Mode (Docker Compose)

**Use Case**: Local development, quick testing, demo presentations

**Key Features**:
- Single-node MongoDB + single-node TapData
- Orchestrated via Docker Compose
- Host network mode, ports directly mapped to host
- Default console access on port 3030

**Artifacts**:
- `docker-compose.yaml`
- `.tap-deploy.env` (environment variables)

**Underlying Execution**:
```bash
docker compose -f docker-compose.yaml up -d
```

### Cloud Mode (Terraform + Kubernetes)

**Use Case**: Production environments on Huawei Cloud CCE, AWS EKS, and other cloud providers

**Key Features**:
- Automatic cloud infrastructure creation (VPC, K8s cluster, ELB/ALB, NAT gateway)
- MongoDB 3-node replica set with automatic cloud disk mounting (EVS/EBS)
- TapData components deployed with multiple replicas for high availability
- Automatic Ingress configuration and public network access

**Artifacts**:
- Terraform configuration: `main.tf`, `terraform.tfvars`
- Helm configuration: `values.yaml`

**Underlying Execution**:
```bash
# 1. Terraform creates infrastructure
terraform init
terraform apply -var-file=terraform.tfvars

# 2. Install MongoDB Community Operator
helm install community-operator mongodb/community-operator \
  --namespace mongodb --create-namespace

# 3. Deploy TapData
helm install tapdata ./deploy-on-kubernetes \
  --namespace tapdata --create-namespace \
  -f values.yaml
```

**Huawei Cloud CCE Example**:
```bash
# 1. Initialize Cloud mode configuration
./tap-deploy init
# Select Cloud mode → Huawei Cloud
# Enter AK/SK, Region, Availability Zones, cluster specs, etc.

# 2. Execute deployment (automatically completes Terraform + Helm)
./tap-deploy apply

# 3. Get access address
kubectl -n tapdata describe ingress tapdata-ingress | grep "kubernetes.io/elb.ip"
```

### On-Prem Mode (Offline Deployment)

**Use Case**: Customer data centers, disconnected environments, internal Harbor registries

**Key Features**:
- Support for creating offline image bundles
- Automatic image loading, tagging, and pushing to internal registry
- Connect to existing K8s clusters by modifying `values.yaml` image prefix

**Complete Workflow**:

```bash
# ===== Online Environment: Create Offline Bundle =====
./tap-deploy bundle --output images-bundle.tar.gz

# ===== Transfer to Offline Environment =====
scp images-bundle.tar.gz user@target-host:/opt/

# ===== Offline Environment: Deploy =====
# 1. Initialize configuration (select On-Prem mode, enter internal Harbor address)
./tap-deploy init

# 2. Execute deployment (automatically completes image load, tag, push, Helm install)
./tap-deploy apply
```

**Underlying Execution**:
```bash
# Load images
docker load -i images-bundle.tar.gz

# Tag and push to internal registry
docker tag tapdata8/tapdata <harbor-registry>/tapdata/tapdata:<version>
docker push <harbor-registry>/tapdata/tapdata:<version>

# Helm deployment
helm install tapdata ./deploy-on-kubernetes \
  --namespace tapdata --create-namespace \
  -f values.yaml
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `./tap-deploy init` | Initialize configuration, interactive wizard generates deployment config files |
| `./tap-deploy plan` | Preview deployment components and content without actual deployment |
| `./tap-deploy apply` | Execute deployment based on configuration |
| `./tap-deploy status` | View current deployment status |
| `./tap-deploy destroy` | Uninstall deployment |
| `./tap-deploy bundle` | Create offline installation bundle (On-Prem scenario) |

### init — Initialize Configuration

```bash
./tap-deploy init
```

**Interactive Process**:
1. Select mode: Lite | Cloud | On-Prem
2. Common parameters: Admin Password, MongoDB URI, Storage Path
3. Cloud/On-Prem specific: Helm Release Name, Namespace, image registry prefix
4. Cloud specific: Access Key/Secret Key, Region, Availability Zones, cluster specs (create new or reuse)

**Generated Configuration Files**:
- Application config: `application.yml`, `agent.yml`, `license.txt` (optional)
- Deployment config:
  - Lite: `docker-compose.yaml`
  - Cloud: `main.tf`, `terraform.tfvars`, `values.yaml`
  - On-Prem: `values.yaml`

### plan — Preview Deployment

```bash
./tap-deploy plan
```

**Example Output**:
```
Deployment Mode: Lite
├── MongoDB (mongo:6.0)
│   └── Single-node replica set, port 27017
└── TapData (tapdata8/tapdata:latest)
    └── Full mode, port 3030
```

### apply — Execute Deployment

```bash
./tap-deploy apply
```

Underlying operations by mode:

| Mode | Underlying Operations |
|------|----------------------|
| Lite | `docker compose -f docker-compose.yaml up -d` |
| Cloud | `terraform apply` → Configure Kubeconfig → `helm install` |
| On-Prem | `docker load` → `docker tag` → `docker push` → `helm install` |

### status — View Status

```bash
./tap-deploy status
```

Underlying operations by mode:

| Mode | Underlying Operations |
|------|----------------------|
| Lite | `docker compose ps` |
| Cloud | `terraform show` + `helm status <release>` |
| On-Prem | `helm status <release>` |

### destroy — Uninstall Deployment

```bash
./tap-deploy destroy
```

Underlying operations by mode:

| Mode | Underlying Operations |
|------|----------------------|
| Lite | `docker compose -f docker-compose.yaml down -v` |
| Cloud | `helm uninstall` → `terraform destroy` |
| On-Prem | `helm uninstall` |

### bundle — Create Offline Installation Bundle

```bash
./tap-deploy bundle --output images-bundle.tar.gz
```

**Bundle Contents**:
- TapData application images (AMD64 / ARM64)
- MongoDB images
- MongoDB Community Operator images
- Other dependency images

---

## Configuration Management

### Application Configuration

TapData application configuration is managed through `application.yml` and `agent.yml`. **Hardcoding into images is strictly prohibited**.

#### application.yml

Core configuration items:

```yaml
spring:
  data:
    mongodb:
      uri: ""                          # MongoDB connection string (injected via template rendering)
      username: ""                     # Username
      password: ""                     # Password
      authenticationDatabase: admin

tapdata:
  mode: cluster                        # Running mode
  conf:
    tapdataPort: '3030'
    backendUrl: ''                     # Backend API URL
    apiServerPort: '3080'
    tapdataJavaOpts: '-Xmx8G -Xms4G'  # Engine JVM options
    tapdataTMJavaOpts: '-Xmx8G -Xms4G' # TM JVM options
```

#### agent.yml

Engine Agent identification configuration:

```yaml
{agentId: <unique-uuid>}              # Auto-generated during deployment
```

### Environment Variables

Containers control runtime behavior through environment variables:

| Environment Variable | Description | Default | Applies To |
|---------------------|-------------|---------|------------|
| `MONGODB_CONNECTION_STRING` | MongoDB connection string | Required | All |
| `MONGODB_USER` | MongoDB username | - | All |
| `MONGODB_PASSWORD` | MongoDB password | - | All |
| `BACKENDURL` | Backend API URL | - | engine/apiserver |
| `MODULE` | Running module | - (full startup) | All |
| `JAVA_VERSION` | JDK version | java17 | All |
| `TZ` | Timezone | Asia/Shanghai | All |
| `LICENSE_HOST` | License server URL | - | All |
| `TAPDATA_WORK_DIR` | Working directory | /tapdata/apps | All |

**MODULE Environment Variable**:

| Value | Component | Description |
|-------|-----------|-------------|
| `frontend` | tapdata-server | Start TM frontend + backend |
| `backend` | tapdata-engine | Start sync engine |
| `apiserver` | tapdata-apiserver | Start API service |
| Not set | Lite mode | Full startup of all modules |

### Sensitive Information Management

- **Docker Compose Mode**: Sensitive information passed via environment variables, not persisted to config files
- **K8s Mode**:
  - MongoDB password: Managed via Secret
  - Image registry authentication: Via `imagePullSecret` or `registry-auth` Secret
  - License: Mounted via ConfigMap
  - TLS certificates: Referenced via Ingress TLS configuration using K8s TLS Secret
- **Terraform**: Cloud provider AK/SK, Kubeconfig, SSH private keys marked as `sensitive`, never output in plaintext in logs

---

## Production Environment Guide

### Resource Planning

#### Production Environment Minimum Configuration

| Component | Replicas | CPU Request/Limit | Memory Request/Limit | Storage |
|-----------|----------|------------------|---------------------|---------|
| tapdata-server | 2 | 500m/2 | 2Gi/4Gi | - |
| tapdata-engine | 2 | 500m/2 | 2Gi/4Gi | - |
| tapdata-apiserver | 2 | 250m/1 | 1Gi/2Gi | - |
| MongoDB | 3-node replica set | 1/2 | 2Gi/4Gi | Data 10Gi + Logs 2Gi |

#### Test Environment Minimum Configuration

| Component | Replicas | CPU Request/Limit | Memory Request/Limit | Storage |
|-----------|----------|------------------|---------------------|---------|
| tapdata-server | 1 | 250m/1 | 1Gi/2Gi | - |
| tapdata-engine | 1 | 250m/1 | 1Gi/2Gi | - |
| tapdata-apiserver | 1 | 250m/500m | 512Mi/1Gi | - |
| MongoDB | 1 node | 500m/1 | 1Gi/2Gi | Data 5Gi + Logs 1Gi |

### Storage Type Recommendations

| Cloud Provider | Recommended Storage | Notes |
|----------------|--------------------|-------|
| Huawei Cloud | SSD (Ultra-High I/O EVS) | Production must use ultra-high I/O to reduce CDC latency |
| AWS | gp3 / io2 EBS | Choose based on throughput requirements |

### High Availability Configuration

- **Database**: Deployed as 3-node replica set
- **TM High Availability**:
  - Default 2 replicas, can modify Deployment replica count
  - Requests load balanced via Load Balancer Service
- **Engine High Availability**:
  - Default 2 replicas, can modify Deployment replica count
  - TM handles task rescheduling
- **Load Balancing**:
  - Huawei Cloud: ELB + Nginx Ingress
  - AWS: ALB + Nginx Ingress

---

## Operations & Maintenance

### Upgrade Strategy

```bash
./tap-deploy apply --version <new-version>
```

Underlying operations by mode:

| Mode | Underlying Operations |
|------|----------------------|
| Lite | `docker compose pull` → `docker compose up -d` |
| Cloud/On-Prem | `helm upgrade tapdata ./deploy-on-kubernetes -n tapdata -f values.yaml --set *.image.tag=<new-version>` |

**Rolling Updates**: K8s Deployment uses RollingUpdate strategy by default, ensuring zero downtime during upgrades. Engine components have built-in SIGTERM monitoring, supporting 30-second graceful shutdown to complete current offset commits before safe exit.

### Log Management

- **Application Logs**:
  - Container path: `/tapdata/apps/logs/`
  - Application automatically handles log compression and expiration deletion
  - K8s mode uses `emptyDir` by default, users can configure PVC for persistence
  - Lite mode mounts to host `./tapdata/logs/`
- **MongoDB Logs**:
  - Container path: `/var/log/mongo/mongod.log`
  - Lite mode mounts to host `./mongodb/logs/`

### Troubleshooting

| Issue | Troubleshooting Method |
|-------|----------------------|
| Pod fails to start | `kubectl -n tapdata describe pod <pod-name>` to view Events |
| Service unreachable | Check Ingress config, ELB/ALB status, security group rules |
| MongoDB connection failure | Check ReplicaSet status: `kubectl get mdb -n tapdata` |
| Engine tasks not executing | Check Engine Pod logs: `kubectl -n tapdata logs <engine-pod>` |
| Image pull failure | Check imagePullSecret config and image registry URL |
| License expired | Check `$TAPDATA_WORK_DIR/license.txt` validity, re-apply |

---

## Technology Stack

### Core Toolchain

| Tool | Version Requirement | Purpose |
|------|--------------------|---------|
| Docker | 20.10+ | Container runtime (Lite mode) |
| Docker Compose | 2.0+ | Container orchestration (Lite mode) |
| Kubernetes | 1.24+ | Container orchestration platform (Cloud/On-Prem mode) |
| Helm | 3.14+ | K8s application package manager |
| Terraform | 1.7+ | Cloud infrastructure orchestration (Cloud mode) |

### Cloud Platform Support

| Cloud Platform | Infrastructure | K8s Service | Storage | Load Balancer |
|----------------|---------------|-------------|---------|---------------|
| Huawei Cloud | VPC, EIP, NAT | CCE | EVS Cloud Disk | ELB |
| AWS | VPC, EIP, NAT | EKS | EBS | ALB |

### Database

- **MongoDB**: 6.0+, managed via MongoDB Community Operator for replica sets
- **ReplicaSet Config**: WiredTiger engine, oplogSizeMB: 1024, journalCompressor: zlib

### Image Building

- **Base Image**: Ubuntu 24.04 (AMD64) / arm64v8/ubuntu:24.04 (ARM64)
- **Runtime**: JDK 8/11/17, Node.js
- **Multi-stage Build**: Base image layer + application layer, reducing build time and storage

---

## Important Notes

- **Network Access**: `tap-deploy init` requires network access to download configuration templates; `tap-deploy apply` requires network access to pull container images. For On-Prem offline scenarios, prepare offline image bundles in advance.
- **Storage Performance**: In Cloud/On-Prem modes, production environments must use "Ultra-High I/O" EVS cloud disks (or local NVMe SSDs) to reduce CDC latency.
- **Signal Handling**: Engine component images have built-in SIGTERM monitoring, supporting 30-second graceful shutdown to complete current offset commits before safe exit.
- **Ingress Compatibility**: Uses vendor-recommended Ingress by default, with security policies configured to expose TapData console access.
- **ARM Compatibility**: All Connectors undergo ARM compilation scanning during build phase; if specific legacy Connectors don't support ARM, contact official support for adapted versions.
- **macOS Compatibility**: When running on macOS, ensure terminal has been granted disk access permissions.

---

## License & Support

- **License Management**: Containers automatically apply for License from License Server on startup (HTTPS + server authentication)
- **License Parameters**:
  - `valid_days`: Validity period (default 30 days)
  - `licenseType`: Type (OP = Private Deployment)
  - `engineLimit`: Engine count limit
- **Manual Specification**: In K8s mode, pre-applied `license.txt` can be mounted via ConfigMap

---

## More Information

- **Detailed Design Document**: [design.md](design.md)
- **GitHub Repository**: https://github.com/tapdata/tapdata-deploy
- **Issue Reporting**: Please submit via GitHub Issues
