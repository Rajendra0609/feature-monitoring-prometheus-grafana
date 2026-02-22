# Production Observability Stack - Kubernetes

This repository contains a complete Kubernetes observability stack including Prometheus, Grafana, and Node Exporter for metrics collection and visualization.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐         ┌─────────────────────┐                    │
│  │   monitoring NS     │         │   node-metrics NS   │                    │
│  │   (restricted)      │         │   (baseline)         │                    │
│  │                     │         │                     │                    │
│  │  ┌───────────────┐  │         │  ┌───────────────┐  │                    │
│  │  │   Prometheus  │  │◄────────┼──│ Node Exporter │  │                    │
│  │  │  StatefulSet  │  │  scrape │  │  DaemonSet    │  │                    │
│  │  │  :9090        │  │         │  │  :9100        │  │                    │
│  │  └───────┬───────┘  │         │  └───────┬───────┘  │                    │
│  │          │          │         │          │          │                    │
│  │  ┌───────▼───────┐  │         │          │          │                    │
│  │  │    Grafana    │  │         │          │          │                    │
│  │  │  Deployment   │  │────────►│          │          │                    │
│  │  │  :3000        │  │ query   │          │          │                    │
│  │  └───────────────┘  │         │          │          │                    │
│  └─────────────────────┘         └──────────┼──────────┘                    │
│                                             │                                 │
└─────────────────────────────────────────────┼─────────────────────────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
                    ▼                         ▼                         ▼
            ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
            │    Jenkins   │          │ Ingress-Nginx│          │  Kube System │
            │   (metrics)  │          │  (metrics)   │          │   (metrics)  │
            └──────────────┘          └──────────────┘          └──────────────┘
```

## Architecture Components

### Namespaces

| Namespace | Security Level | Purpose |
|-----------|----------------|---------|
| `monitoring` | Restricted | Prometheus & Grafana deployment |
| `node-metrics` | Baseline | Node Exporter for node metrics |

### Core Components

#### Node Exporter
- **Type**: DaemonSet
- **Namespace**: node-metrics
- **Port**: 9100
- **Purpose**: Exports node-level metrics (CPU, memory, disk, network)
- **Image**: `quay.io/prometheus/node-exporter:v1.8.1`

#### Prometheus
- **Type**: StatefulSet
- **Namespace**: monitoring
- **Port**: 9090
- **Storage**: 10Gi PVC (local-storage)
- **Retention**: 7 days / 5GB
- **Image**: `prom/prometheus:v2.49.0`

**Scrape Targets:**
- Node Exporter (node-metrics namespace)
- Jenkins metrics
- Kube-state-metrics
- Kubelet
- Cadvisor
- Kube-apiserver
- Ingress-nginx metrics

#### Grafana
- **Type**: Deployment
- **Namespace**: monitoring
- **Port**: 3000
- **Storage**: 5Gi PVC (local-storage)
- **Image**: `grafana/grafana:10.4.2`

### Storage

- **StorageClass**: local-storage
- **Provisioner**: kubernetes.io/no-provisioner
- **Binding Mode**: WaitForFirstConsumer
- **Reclaim Policy**: Retain

## Prerequisites

- Kubernetes cluster (v1.19+)
- kubectl CLI configured
- Worker node name (for PV configuration)

## Installation

### Quick Start

```
bash
# Apply all resources
./apply-all.sh

# With custom worker node name
WORKER_NODE_NAME=my-worker ./apply-all.sh
```

### Manual Installation

Apply resources in order:

```
bash
# 1. Namespaces
kubectl apply -f 00-namespaces/

# 2. Storage (set WORKER_NODE_NAME if needed)
kubectl apply -f 05-storage/

# 3. Node Exporter
kubectl apply -f 01-node-metrics/

# 4. Monitoring (Prometheus + Grafana)
kubectl apply -f 02-monitoring/

# 5. Other integrations
kubectl apply -f 03-ingress-nginx-metrics/
kubectl apply -f 04-jenkins-integration/
```

## Accessing Services

### Port Forwarding

```
bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Node Exporter (specific pod)
kubectl port-forward -n node-metrics svc/node-exporter 9100:9100
```

### NodePort Services

Network policies are configured to allow NodePort access:
- Prometheus: NodePort
- Grafana: NodePort

## Configuration

### Prometheus Configuration

Edit the ConfigMap:
```
bash
kubectl edit configmap prometheus-config -n monitoring
```

### Grafana Configuration

Datasources are auto-provisioned via ConfigMap. Admin credentials are stored in a Secret.

## Cleanup

### Remove Specific Namespace
```
bash
# Using the cleanup script
./scripts/cleanup-namespace.sh monitoring

# Or manually
kubectl delete namespace monitoring
```

### Complete Cleanup
```
bash
# Remove all resources
kubectl delete -f 02-monitoring/
kubectl delete -f 01-node-metrics/
kubectl delete -f 05-storage/
kubectl delete -f 00-namespaces/
```

## Directory Structure

```
prod-observability-v2/
├── 00-namespaces/
│   └── 00-namespaces.yaml          # Namespace definitions
├── 01-node-metrics/
│   ├── 10-node-exporter-service.yaml
│   ├── 20-node-exporter-daemonset.yaml
│   └── 30-node-exporter-networkpolicy.yaml
├── 02-monitoring/
│   ├── grafana/                     # Grafana deployment
│   ├── prometheus/                  # Prometheus StatefulSet
│   └── networkpolicies/            # Network policies
├── 03-ingress-nginx-metrics/
│   └── 10-ingress-metrics-service.yaml
├── 04-jenkins-integration/
│   ├── 10-jenkins-namespace-label.yaml
│   └── 15-jenkins-metrics-service.yaml
├── 05-storage/
│   ├── 10-storageclass.yaml
│   ├── 20-local-pvs.yaml
│   └── pv-prometheus-grafana.yaml
├── scripts/
│   └── cleanup-namespace.sh        # Namespace cleanup utility
├── apply-all.sh                    # Main deployment script
├── cleanup-namespace.sh            # Root cleanup script
└── README.md                        # This file
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WORKER_NODE_NAME` | Worker node name for PV binding | None (required for PV) |

## Security Considerations

- Pod Security Standards enforced
- Network policies restrict traffic between namespaces
- Non-root containers with read-only filesystems
- Seccomp profiles enabled
- Dropped all capabilities

## Troubleshooting

### Check Pod Status
```
bash
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
```

### View Logs
```
bash
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring statefulset/prometheus
kubectl logs -n node-metrics ds/node-exporter
```

### Check PVC Status
```
bash
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n monitoring
```

## Version Information

| Component | Version |
|-----------|---------|
| Node Exporter | v1.8.1 |
| Prometheus | v2.49.0 |
| Grafana | 10.4.2 |

## License

Internal use only - Production Observability Stack
