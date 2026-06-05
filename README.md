# Production Observability Stack — Kubernetes (ArgoCD GitOps)

This repository is the **GitOps source of truth** for the production observability stack.
All changes are applied to the cluster by ArgoCD — **no manual `kubectl apply` needed**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────┐         ┌─────────────────────┐                     │
│  │   monitoring NS     │         │   node-metrics NS   │                     │
│  │   (restricted)      │         │   (baseline)        │                     │
│  │                     │         │                     │                     │
│  │  ┌───────────────┐  │         │  ┌───────────────┐  │                     │
│  │  │   Prometheus  │◄─┼─────────┼──│ Node Exporter │  │                     │
│  │  │  StatefulSet  │  │  scrape │  │  DaemonSet    │  │                     │
│  │  │  :9090        │  │         │  │  :9100        │  │                     │
│  │  └───────┬───────┘  │         │  └───────────────┘  │                     │
│  │          │          │         └─────────────────────┘                     │
│  │  ┌───────▼───────┐  │                                                      │
│  │  │    Grafana    │  │  query                                               │
│  │  │  Deployment   │──┼──► Prometheus :9090                                 │
│  │  │  :3000        │  │                                                      │
│  │  └───────────────┘  │                                                      │
│  └─────────────────────┘                                                      │
│                                                                               │
│  Also scraped by Prometheus:                                                  │
│    Jenkins (jenkins NS) · Ingress-Nginx · Kubelet · cAdvisor · kube-apiserver│
└───────────────────────────────────────────────────────────────────────────────┘
```

## Component Versions

| Component     | Version      |
|---------------|--------------|
| Node Exporter | v1.8.1       |
| Prometheus    | v2.49.0      |
| Grafana       | 10.4.2       |

---

## GitOps Workflow (ArgoCD)

```
Git Push → ArgoCD detects diff → syncs to cluster (automated)
```

All resources are managed through the **App of Apps** pattern:

```
observability-root  (argocd/01-app-of-apps.yaml)
├── observability-namespaces    [wave 0]  →  00-namespaces/
├── observability-storage       [wave 1]  →  05-storage/
├── observability-node-metrics  [wave 2]  →  01-node-metrics/
├── observability-monitoring    [wave 3]  →  02-monitoring/ (recursive)
│   ├── prometheus/
│   ├── grafana/
│   └── networkpolicies/
├── observability-ingress-nginx [wave 4]  →  03-ingress-nginx-metrics/
└── observability-jenkins       [wave 4]  →  04-jenkins-integration/
```

Sync waves guarantee ordering: namespaces exist before workloads, storage before StatefulSets.

---

## Bootstrap (First-Time Setup)

> Only needed once. After this, ArgoCD manages everything automatically.

### Prerequisites

- ArgoCD installed and running in your cluster (`argocd` namespace)
- `kubectl` configured against your cluster
- This repository pushed to your Git remote

### Step 1 — Update the repo URL

Replace `REPLACE_WITH_YOUR_REPO_URL` in every file under `argocd/` with your actual Git remote, e.g.:

```bash
find argocd/ -name "*.yaml" -exec sed -i \
  's|REPLACE_WITH_YOUR_REPO_URL|https://github.com/YOUR_ORG/prod-observability-v2.git|g' {} +
```

### Step 2 — Update the PersistentVolume node name

Edit `05-storage/20-local-pvs.yaml` and replace `k8s-worker1` with your actual worker hostname:

```bash
kubectl get nodes  # find your worker node name
```

### Step 3 — Apply the AppProject and Root Application

```bash
# Create the ArgoCD project
kubectl apply -f argocd/00-project.yaml

# Bootstrap the App of Apps (this one-time apply triggers everything else)
kubectl apply -f argocd/01-app-of-apps.yaml
```

ArgoCD will now reconcile all child Applications automatically in the correct order.

### Step 4 — Watch the sync

```bash
# Via CLI
argocd app list
argocd app get observability-root
argocd app get observability-monitoring

# Via UI — open the ArgoCD dashboard and look for the observability-root app
```

---

## Making Changes

```bash
# 1. Edit the manifests in this repo
vi 02-monitoring/prometheus/20-configmap.yaml

# 2. Commit and push
git add -A && git commit -m "feat: add alertmanager scrape target"
git push

# 3. ArgoCD auto-syncs within 3 minutes (default polling interval)
#    Or trigger immediately:
argocd app sync observability-monitoring
```

---

## Accessing Services

### NodePort (direct)

| Service    | NodePort | URL                          |
|------------|----------|------------------------------|
| Grafana    | 32000    | `http://<NODE_IP>:32000`     |
| Prometheus | 32090    | `http://<NODE_IP>:32090`     |

### Port Forward (local access)

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

---

## Directory Structure

```
prod-observability-v2/
├── .argocdignore                    ← tells ArgoCD what NOT to apply
├── argocd/
│   ├── 00-project.yaml             ← AppProject (observability)
│   ├── 01-app-of-apps.yaml         ← Root Application — bootstrap this once
│   └── apps/
│       ├── 01-namespaces-app.yaml  ← manages 00-namespaces/  [wave 0]
│       ├── 02-storage-app.yaml     ← manages 05-storage/     [wave 1]
│       ├── 03-node-metrics-app.yaml← manages 01-node-metrics/ [wave 2]
│       ├── 04-monitoring-app.yaml  ← manages 02-monitoring/  [wave 3]
│       ├── 05-ingress-nginx-app.yaml← manages 03-ingress-nginx-metrics/ [wave 4]
│       └── 06-jenkins-app.yaml     ← manages 04-jenkins-integration/ [wave 4]
├── 00-namespaces/
│   └── 00-namespaces.yaml          ← monitoring + node-metrics namespaces
├── 01-node-metrics/
│   ├── 10-node-exporter-service.yaml
│   ├── 20-node-exporter-daemonset.yaml
│   └── 30-node-exporter-networkpolicy.yaml
├── 02-monitoring/
│   ├── grafana/
│   │   ├── 10-secret.yaml          ← admin credentials (consider Sealed Secrets)
│   │   ├── 20-provisioning-configmap.yaml
│   │   ├── 30-pvc.yaml
│   │   ├── 40-deployment.yaml
│   │   └── 50-service.yaml
│   ├── networkpolicies/
│   │   ├── 00-default-deny.yaml
│   │   ├── 10-prometheus.yaml
│   │   ├── 20-grafana.yaml
│   │   ├── 30-grafana-nodeport-allow.yaml
│   │   └── 30-prometheus-nodeport-allow.yaml
│   └── prometheus/
│       ├── 10-rbac.yaml            ← ServiceAccount + ClusterRole (discovery)
│       ├── 15-rbac-kubelet.yaml    ← ClusterRole for kubelet node metrics
│       ├── 20-configmap.yaml       ← prometheus.yml scrape config
│       ├── 30-service.yaml
│       └── 40-statefulset.yaml
├── 03-ingress-nginx-metrics/
│   └── 10-ingress-metrics-service.yaml
├── 04-jenkins-integration/
│   ├── 10-jenkins-namespace-label.yaml
│   └── 15-jenkins-metrics-service.yaml
└── 05-storage/
    ├── 10-storageclass.yaml        ← local-storage StorageClass
    └── 20-local-pvs.yaml           ← PVs for Prometheus (10Gi) and Grafana (5Gi)
```

---

## Security Notes

### Secret Management

`02-monitoring/grafana/10-secret.yaml` stores the Grafana admin password in plaintext.
**For production, replace with one of:**

- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) — encrypt secrets in Git
- [External Secrets Operator](https://external-secrets.io/) — pull secrets from Vault / AWS SSM
- ArgoCD Vault Plugin — render secrets at sync time

### Pod Security

- All containers run as non-root with read-only root filesystems
- `ALL` capabilities dropped
- Seccomp `RuntimeDefault` profiles applied
- Network Policies restrict inter-namespace traffic

---

## Troubleshooting

```bash
# Check ArgoCD sync status
argocd app list
argocd app get observability-monitoring

# Force a sync
argocd app sync observability-monitoring --prune

# Check pod status
kubectl get pods -n monitoring
kubectl get pods -n node-metrics

# View logs
kubectl logs -n monitoring statefulset/prometheus
kubectl logs -n monitoring deployment/grafana
kubectl logs -n node-metrics ds/node-exporter

# Check PVC binding
kubectl get pvc -A
```

---

## Environment Variables (PV Configuration)

Edit `05-storage/20-local-pvs.yaml` and replace the `values` hostname directly.
The old `WORKER_NODE_NAME` shell variable from `apply-all.sh` is no longer used.

```yaml
values: ["your-worker-hostname"]   # output of: kubectl get nodes
```
