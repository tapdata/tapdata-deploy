# TapData One-Deploy

[English](README.md) | [中文](README_zh.md)

## Overview

TapData One-Deploy is the official automated deployment tool for TapData, providing unified delivery from single-node testing to enterprise-grade cloud-native environments.

**Core Vision**: *"Build Once, Run Anywhere"*

### Deployment Modes

| Mode | Scenario | Tech Stack |
|------|----------|------------|
| **Lite** | Local development, quick POC | Docker Compose |
| **Cloud** | Huawei Cloud/AWS production | Terraform + Kubernetes |
| **On-Prem** | Customer data center, offline | Offline Image Bundle + Harbor |

---

## Key Features

- **Zero Installation**: Download and run directly, supports Linux/macOS
- **Interactive Configuration**: Command-line wizard auto-generates configuration
- **Full Scenario Coverage**: Lite / Cloud / On-Prem modes
- **Multi-Architecture**: AMD64 and ARM64 (Huawei Kunpeng/Phytium)

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

### Uninstall

```bash
./tap-deploy destroy
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `./tap-deploy init` | Initialize configuration, interactive wizard generates config files |
| `./tap-deploy plan` | Preview deployment without actual execution |
| `./tap-deploy apply` | Execute deployment |
| `./tap-deploy status` | View deployment status |
| `./tap-deploy destroy` | Uninstall deployment |
| `./tap-deploy bundle` | Create offline bundle (On-Prem scenario) |

---

## Deployment Modes

### Lite Mode

**Use Case**: Local development, quick testing, demo presentations

**Features**: Single-node MongoDB + TapData, Docker Compose orchestration, 5-minute quick startup

### Cloud Mode

**Use Case**: Production environments on Huawei Cloud CCE, AWS EKS

**Features**:
- Automatic cloud infrastructure creation (VPC, K8s cluster, ELB/ALB, NAT gateway)
- MongoDB 3-node replica set with cloud disk mounting
- TapData multi-replica deployment for high availability

**Huawei Cloud CCE Example**:
```bash
# 1. Initialize configuration (select Cloud mode → Huawei Cloud, enter AK/SK, Region, etc.)
./tap-deploy init

# 2. Execute deployment (automatically completes Terraform + Helm)
./tap-deploy apply

# 3. Get access address
kubectl -n tapdata describe ingress tapdata-ingress | grep "kubernetes.io/elb.ip"
```

### On-Prem Mode

**Use Case**: Customer data centers, disconnected environments, internal Harbor registries

**Features**: Offline image bundle creation, automatic image loading, tagging, and pushing

**Complete Workflow**:
```bash
# Online environment: Create offline bundle
./tap-deploy bundle --output images-bundle.tar.gz

# Transfer to offline environment
scp images-bundle.tar.gz user@target-host:/opt/

# Offline environment: Deploy (select On-Prem mode, enter internal Harbor address)
./tap-deploy init
./tap-deploy apply
```

---

## Production Guidelines

### Resource Planning

**Production**: tapdata-server/engine/apiserver 2 replicas each, MongoDB 3-node replica set

**Storage Recommendations**:
- Huawei Cloud: SSD (Ultra-High I/O EVS)
- AWS: gp3 / io2 EBS

### High Availability

- Database: 3-node replica set
- Application: Multi-replica + load balancing
- Rolling updates: Zero-downtime upgrades, 30s graceful shutdown

---

## Operations

### Upgrade

```bash
./tap-deploy apply --version <new-version>
```

Supports rolling updates with zero downtime.

### Troubleshooting

| Issue | Troubleshooting |
|-------|----------------|
| Pod fails to start | `kubectl -n tapdata describe pod <pod-name>` |
| Service unreachable | Check Ingress, ELB/ALB, security groups |
| MongoDB connection failure | `kubectl get mdb -n tapdata` |
| License expired | Check `$TAPDATA_WORK_DIR/license.txt` |

---

## Technology Stack

- **Containers**: Docker 20.10+, Docker Compose 2.0+
- **Orchestration**: Kubernetes 1.24+, Helm 3.14+
- **Infrastructure**: Terraform 1.7+ (Huawei Cloud CCE / AWS EKS)
- **Database**: MongoDB 6.0+ (Community Operator managed replica sets)
- **Architecture**: AMD64 / ARM64 (Ubuntu 24.04 base image)

---

## Important Notes

- **Network**: `init` downloads config templates, `apply` pulls images (On-Prem requires offline bundle)
- **Storage**: Use ultra-high I/O storage in production to reduce CDC latency
- **ARM Compatibility**: All Connectors verified with ARM compilation
- **macOS**: Ensure terminal has disk access permissions

---

## License Management

Containers automatically apply for License from License Server on startup (HTTPS + server authentication):
- `valid_days`: Validity period (default 30 days)
- `licenseType`: Type (OP = Private Deployment)
- `engineLimit`: Engine count limit

In K8s mode, pre-applied `license.txt` can be mounted via ConfigMap

---

## More Information

- **GitHub Repository**: https://github.com/tapdata/tapdata-deploy
- **Issue Reporting**: Please submit via GitHub Issues
