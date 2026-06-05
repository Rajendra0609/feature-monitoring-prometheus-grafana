# ArgoCD GitOps — Complete Learning & Hands-On Project Guide

> **Level:** Beginner → Advanced | **Cluster:** 1 Master + 1 Worker | **ArgoCD:** Pre-installed

---

## Table of Contents

1. [GitOps Fundamentals](#1-gitops-fundamentals)
2. [ArgoCD Architecture & Components](#2-argocd-architecture--components)
3. [Installation Verification](#3-installation-verification)
4. [Repository Structure](#4-repository-structure)
5. [Application Deployment](#5-application-deployment)
6. [Sync & Auto-Sync Configurations](#6-sync--auto-sync-configurations)
7. [Rollback Procedures](#7-rollback-procedures)
8. [Health Checks & Status](#8-health-checks--status)
9. [Multi-Environment Setup (Dev / QA / Prod)](#9-multi-environment-setup-dev--qa--prod)
10. [Helm Integration](#10-helm-integration)
11. [Kustomize Integration](#11-kustomize-integration)
12. [RBAC Configuration](#12-rbac-configuration)
13. [Secrets Management](#13-secrets-management)
14. [CI/CD Integration](#14-cicd-integration)
15. [Monitoring & Troubleshooting](#15-monitoring--troubleshooting)
16. [Real-World Production Use Cases](#16-real-world-production-use-cases)
17. [Hands-On Labs & Project Exercises](#17-hands-on-labs--project-exercises)
18. [Best Practices Cheat Sheet](#18-best-practices-cheat-sheet)

---

## 1. GitOps Fundamentals

### 1.1 What is GitOps?

GitOps is an operational framework that applies DevOps best practices (version control, collaboration, compliance, CI/CD) to infrastructure automation. The core idea is: **Git is the single source of truth** for both application code and infrastructure configuration.

```
Developer → git push → Git Repository → GitOps Operator → Kubernetes Cluster
                          (Desired State)                    (Actual State)
```

### 1.2 The Four Core GitOps Principles

| # | Principle | Description |
|---|-----------|-------------|
| 1 | **Declarative** | The entire system is described declaratively (YAML manifests, Helm charts, Kustomize overlays). You describe *what* you want, not *how* to get there. |
| 2 | **Versioned & Immutable** | The desired state is stored in Git, providing a complete audit trail and the ability to roll back to any previous state. |
| 3 | **Pulled Automatically** | Software agents (like ArgoCD) continuously pull the desired state from Git and apply it to the cluster. No external push access needed. |
| 4 | **Continuously Reconciled** | Agents continuously ensure the actual state matches the desired state and alert or auto-heal when drift is detected. |

### 1.3 GitOps vs. Traditional CI/CD

```
Traditional CI/CD (Push-Based)           GitOps (Pull-Based)
─────────────────────────────           ────────────────────
CI/CD Pipeline ──push──> Cluster         Git Repo <──pull── ArgoCD Agent
     │                                       │                    │
     └── Has kubectl credentials             └── Desired State    └── Watches Cluster
     └── Direct cluster access               └── Git commits      └── Reconciles drift
     └── No drift detection                  └── Audit log        └── Alerts on diff
```

**Key Differences:**

- **Security:** GitOps removes direct cluster access from CI pipelines. Only the ArgoCD agent (running inside the cluster) has kubectl access.
- **Audit Trail:** Every change is a Git commit — who changed what, when, and why.
- **Self-Healing:** ArgoCD detects and corrects configuration drift automatically.
- **Rollback:** Git revert = instant rollback, no need to re-run pipelines.

### 1.4 GitOps Workflows

**The App of Apps Pattern (used in production):**

```
Git Repo
├── apps/                         ← Root ArgoCD Application (App of Apps)
│   ├── production/
│   │   ├── app-frontend.yaml     ← ArgoCD Application manifest
│   │   ├── app-backend.yaml
│   │   └── app-database.yaml
│   └── staging/
│       └── ...
└── manifests/                    ← Actual Kubernetes manifests
    ├── frontend/
    ├── backend/
    └── database/
```

---

## 2. ArgoCD Architecture & Components

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    argocd namespace                       │   │
│  │                                                           │   │
│  │  ┌─────────────┐   ┌──────────────┐   ┌──────────────┐  │   │
│  │  │  API Server  │   │  Repo Server │   │  Application │  │   │
│  │  │  (argocd-   │   │  (argocd-   │   │  Controller  │  │   │
│  │  │  server)    │   │  repo-      │   │  (argocd-   │  │   │
│  │  │             │   │  server)    │   │  application │  │   │
│  │  │  - REST API │   │             │   │  -controller)│  │   │
│  │  │  - gRPC API │   │  - Clones   │   │              │  │   │
│  │  │  - Web UI   │   │    repos    │   │  - Watches   │  │   │
│  │  │  - Auth     │   │  - Renders  │   │    cluster   │  │   │
│  │  │  - Webhooks │   │    manifests│   │  - Reconciles│  │   │
│  │  └─────────────┘   └──────────────┘   └──────────────┘  │   │
│  │                                                           │   │
│  │  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │   │
│  │  │   Redis      │   │    Dex       │   │  ArgoCD      │  │   │
│  │  │  (Cache)     │   │  (OIDC SSO)  │   │  Notifications│  │   │
│  │  └──────────────┘   └──────────────┘   └──────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   App 1  │  │   App 2  │  │   App 3  │  │  Other NS    │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────┘
          ▲                          │
          │ Pull                     │ Reconcile
          ▼                          ▼
┌─────────────────┐        ┌─────────────────┐
│   Git Repository│        │  Target Cluster │
│   (GitHub/GitLab│        │  (same or remote│
│   /Bitbucket)   │        │   cluster)      │
└─────────────────┘        └─────────────────┘
```

### 2.2 Core Components Explained

**argocd-server (API Server)**
- Exposes the ArgoCD REST and gRPC API
- Serves the Web UI (accessible via browser)
- Handles authentication (local users, SSO via Dex/OIDC)
- Processes CLI commands and webhook events
- Port: `443` (HTTPS) and `80` (HTTP redirect)

**argocd-repo-server (Repository Server)**
- Clones and caches Git repositories
- Renders Kubernetes manifests from: raw YAML, Helm, Kustomize, Jsonnet
- Isolated process — does NOT have Kubernetes API access
- Acts as a manifest generation service

**argocd-application-controller (App Controller)**
- The heart of ArgoCD — runs the reconciliation loop
- Continuously watches desired state (Git) vs. actual state (Kubernetes)
- Invokes sync operations
- Reports application health and sync status
- Uses informers/watchers via Kubernetes API

**Redis**
- Caches application state, repo metadata, and cluster info
- Reduces load on the Kubernetes API server
- NOT a persistent store — data is rebuilt on restart

**Dex**
- Optional OpenID Connect (OIDC) provider
- Enables SSO integration with GitHub, GitLab, LDAP, SAML, etc.

**argocd-notifications**
- Sends notifications (Slack, email, Teams, PagerDuty, etc.) on sync events, health changes

### 2.3 Key Concepts

| Concept | Description |
|---------|-------------|
| **Application** | A CRD (`Application`) that maps a Git source to a Kubernetes destination |
| **Project** | A logical grouping of applications with access controls (`AppProject` CRD) |
| **Repository** | A Git repo registered with ArgoCD (can be HTTP/SSH/Helm repo) |
| **Sync** | The process of making the actual state match the desired (Git) state |
| **Sync Status** | `Synced` / `OutOfSync` — does Git match the cluster? |
| **Health Status** | `Healthy` / `Degraded` / `Progressing` / `Missing` — is the app working? |
| **Drift** | When someone manually changes the cluster state (bypassing Git) |
| **Self-Heal** | ArgoCD automatically reverts manual changes to match Git state |

---

## 3. Installation Verification

Since ArgoCD is already installed, verify the full setup is healthy before proceeding.

### 3.1 Verify All Pods Are Running

```bash
# Check all ArgoCD pods
kubectl get pods -n argocd

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0                    1/1     Running   0          5m
# argocd-applicationset-controller-xxx               1/1     Running   0          5m
# argocd-dex-server-xxx                              1/1     Running   0          5m
# argocd-notifications-controller-xxx                1/1     Running   0          5m
# argocd-redis-xxx                                   1/1     Running   0          5m
# argocd-repo-server-xxx                             1/1     Running   0          5m
# argocd-server-xxx                                  1/1     Running   0          5m
```

### 3.2 Verify Services

```bash
kubectl get svc -n argocd

# KEY SERVICES:
# argocd-server        ClusterIP  10.x.x.x  <none>  80/TCP,443/TCP
# argocd-repo-server   ClusterIP  10.x.x.x  <none>  8081/TCP
# argocd-redis         ClusterIP  10.x.x.x  <none>  6379/TCP
```

### 3.3 Access the ArgoCD Web UI

**Option A: Port-Forward (recommended for local/lab)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
```

**Option B: NodePort (for VM/bare-metal cluster)**
```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort"}}'

# Get the NodePort
kubectl get svc argocd-server -n argocd
# Access: https://<NODE_IP>:<NODE_PORT>
```

**Option C: LoadBalancer**
```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

### 3.4 Get Initial Admin Password

```bash
# ArgoCD stores the initial admin password as a secret
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Login via CLI
argocd login localhost:8080 \
  --username admin \
  --password <password-from-above> \
  --insecure

# IMPORTANT: Change the default password immediately
argocd account update-password
```

### 3.5 Install ArgoCD CLI

```bash
# Linux
curl -sSL -o argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# macOS
brew install argocd

# Verify
argocd version
```

### 3.6 Verify ArgoCD CRDs

```bash
kubectl get crd | grep argoproj
# Expected:
# applications.argoproj.io
# applicationsets.argoproj.io
# appprojects.argoproj.io
```

---

## 4. Repository Structure

A well-structured GitOps repository is critical. Below are two common patterns.

### 4.1 Monorepo Structure (Recommended for Small Teams)

```
gitops-repo/
│
├── README.md
│
├── apps/                              # ArgoCD Application manifests
│   ├── base/
│   │   └── namespace.yaml
│   ├── dev/
│   │   ├── app-frontend.yaml
│   │   ├── app-backend.yaml
│   │   └── app-database.yaml
│   ├── qa/
│   │   ├── app-frontend.yaml
│   │   ├── app-backend.yaml
│   │   └── app-database.yaml
│   └── prod/
│       ├── app-frontend.yaml
│       ├── app-backend.yaml
│       └── app-database.yaml
│
├── manifests/                         # Raw Kubernetes manifests
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── configmap.yaml
│   ├── backend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── database/
│       ├── statefulset.yaml
│       ├── service.yaml
│       └── pvc.yaml
│
├── helm/                              # Helm-based deployments
│   ├── frontend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-qa.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── _helpers.tpl
│   └── backend/
│       └── ...
│
├── kustomize/                         # Kustomize-based deployments
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── patch-replicas.yaml
│       ├── qa/
│       │   ├── kustomization.yaml
│       │   └── patch-replicas.yaml
│       └── prod/
│           ├── kustomization.yaml
│           ├── patch-replicas.yaml
│           └── patch-resources.yaml
│
└── projects/                          # ArgoCD AppProject definitions
    ├── dev-project.yaml
    ├── qa-project.yaml
    └── prod-project.yaml
```

### 4.2 Multi-Repo Structure (Recommended for Large Teams)

```
# Repository 1: Application Config Repo (ops team manages)
config-repo/
├── apps/             # ArgoCD Application definitions
├── projects/         # ArgoCD AppProject definitions
└── clusters/         # Cluster-level config

# Repository 2: Application Source Repo (dev team manages)
app-repo/
├── src/              # Application source code
├── Dockerfile
└── helm/             # Helm chart for the application

# Repository 3: Infrastructure Repo
infra-repo/
├── terraform/        # Infrastructure as Code
└── kubernetes/       # Base Kubernetes config (RBAC, namespaces)
```

### 4.3 Create Your First GitOps Repository

```bash
# Initialize a new GitOps repository
mkdir my-gitops-repo && cd my-gitops-repo
git init

# Create directory structure
mkdir -p {apps/{dev,qa,prod},manifests/{frontend,backend},\
  helm/myapp/templates,kustomize/{base,overlays/{dev,qa,prod}},projects}

# Create a sample namespace manifest
cat > manifests/frontend/namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-dev
  labels:
    environment: dev
    managed-by: argocd
EOF

# Push to GitHub/GitLab
git add .
git commit -m "feat: initialize gitops repository structure"
git remote add origin https://github.com/<your-username>/my-gitops-repo.git
git push -u origin main
```

---

## 5. Application Deployment

### 5.1 ArgoCD Application Manifest Explained

An `Application` is the central CRD in ArgoCD. It defines:
- **Where** to pull the desired state from (Git source)
- **Where** to deploy it (Kubernetes destination)
- **How** to sync it (sync policy)

```yaml
# apps/dev/app-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-dev                         # Unique name in ArgoCD
  namespace: argocd                          # Always deploy Application CRD in argocd ns
  labels:
    environment: dev
    team: frontend
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: frontend-team
  finalizers:
    - resources-finalizer.argocd.argoproj.io # Ensures k8s resources are deleted when app is deleted
spec:
  project: dev-project                       # ArgoCD project (access control boundary)

  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD                     # Branch, tag, or commit SHA
    path: manifests/frontend                 # Path within the repo

  destination:
    server: https://kubernetes.default.svc   # In-cluster (use actual URL for remote clusters)
    namespace: frontend-dev                  # Target namespace

  syncPolicy:
    automated:
      prune: true                            # Delete resources removed from Git
      selfHeal: true                         # Revert manual changes to match Git
    syncOptions:
      - CreateNamespace=true                 # Auto-create namespace if missing
      - PrunePropagationPolicy=foreground    # Wait for resources to be deleted
      - ApplyOutOfSyncOnly=true              # Only sync resources that are out of sync
    retry:
      limit: 5                               # Retry up to 5 times on failure
      backoff:
        duration: 5s                         # Initial retry delay
        factor: 2                            # Exponential backoff multiplier
        maxDuration: 3m                      # Maximum retry delay
```

### 5.2 Deploy Your First Application (Hands-On)

**Step 1: Create sample application manifests**

```bash
# manifests/frontend/deployment.yaml
cat > manifests/frontend/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend-dev
  labels:
    app: frontend
    version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        version: "1.0.0"
    spec:
      containers:
      - name: frontend
        image: nginx:1.25.3
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
EOF

# manifests/frontend/service.yaml
cat > manifests/frontend/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: frontend-dev
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

**Step 2: Register the Git repository with ArgoCD**

```bash
# For public repo (no credentials needed)
argocd repo add https://github.com/<your-username>/my-gitops-repo.git

# For private repo (HTTPS)
argocd repo add https://github.com/<your-username>/my-gitops-repo.git \
  --username <github-username> \
  --password <personal-access-token>

# For private repo (SSH)
argocd repo add git@github.com:<your-username>/my-gitops-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Verify repo is registered
argocd repo list
```

**Step 3: Create the ArgoCD Application**

```bash
# Method 1: Via CLI
argocd app create frontend-dev \
  --project default \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path manifests/frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace frontend-dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Method 2: Apply the YAML manifest (preferred GitOps way)
kubectl apply -f apps/dev/app-frontend.yaml

# Check status
argocd app get frontend-dev
argocd app list
```

**Step 4: Trigger initial sync**

```bash
# Manual sync (if auto-sync is not configured)
argocd app sync frontend-dev

# Watch the sync in real-time
argocd app wait frontend-dev --health

# Verify Kubernetes resources were created
kubectl get all -n frontend-dev
```

### 5.3 App of Apps Pattern

The App of Apps pattern uses one ArgoCD Application to manage all other Applications. This is the preferred production pattern.

```yaml
# apps/root-app.yaml — The "root" application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: apps/dev                           # Points to the folder containing ALL app manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd                        # Applications CRDs live in argocd namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
# Deploy only the root app — all children auto-deploy
kubectl apply -f apps/root-app.yaml
argocd app sync root-app

# All child applications will appear in the UI automatically
argocd app list
```

---

## 6. Sync & Auto-Sync Configurations

### 6.1 Sync Phases & Waves

ArgoCD applies resources in phases and waves, giving you control over deployment ordering.

```
Phase 1: PreSync Hooks   →   Phase 2: Sync (Waves)   →   Phase 3: PostSync Hooks
         (run before sync)            Wave 0                    (run after sync)
                                      Wave 1                           │
                                      Wave 2                    SyncFail Hook
                                      ...                       (on failure only)
```

**Using sync waves for ordered deployments:**

```yaml
# Database — deploys first (wave 0)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  annotations:
    argocd.argoproj.io/sync-wave: "0"       # Deploy first

---
# Backend — waits for DB (wave 1)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "1"       # Deploy after wave 0 completes

---
# Frontend — waits for backend (wave 2)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "2"       # Deploy last
```

### 6.2 Sync Hooks

Hooks are Kubernetes Jobs that run at specific phases of the sync lifecycle.

```yaml
# Pre-sync hook: Run database migrations before deploying
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync               # Run before sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation  # Clean up previous runs
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: myapp:latest
        command: ["python", "manage.py", "migrate"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
```

```yaml
# Post-sync hook: Run smoke tests after deployment
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded  # Delete only on success
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: test
        image: curlimages/curl:latest
        command:
        - sh
        - -c
        - |
          curl -f http://frontend-svc/health || exit 1
          echo "Smoke test passed!"
```

### 6.3 Auto-Sync Policy Reference

```yaml
syncPolicy:
  automated:
    prune: true          # Remove resources deleted from Git (USE WITH CAUTION in prod)
    selfHeal: true       # Revert manual kubectl changes to match Git
    allowEmpty: false    # Prevent syncing if the source renders zero resources (safety net)

  syncOptions:
    - Validate=true                    # Run kubectl --dry-run=client before applying
    - CreateNamespace=true             # Create destination namespace if missing
    - PrunePropagationPolicy=foreground # foreground/background/orphan
    - PruneLast=true                   # Prune resources AFTER all others are synced (safer)
    - ApplyOutOfSyncOnly=true          # Only apply changed resources (faster, less noise)
    - ServerSideApply=true             # Use server-side apply (better for large CRDs)
    - RespectIgnoreDifferences=true    # Respect ignoreDifferences during sync

  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### 6.4 Ignore Differences

Sometimes you want ArgoCD to ignore certain fields (e.g., replica counts managed by HPA, or annotations added by other controllers):

```yaml
spec:
  ignoreDifferences:
  # Ignore HPA-managed replica count
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas

  # Ignore a specific annotation on all resources
  - group: "*"
    kind: "*"
    managedFieldsManagers:
    - kube-controller-manager

  # Ignore a field using JQ expression
  - group: apps
    kind: Deployment
    name: frontend
    jqPathExpressions:
    - .spec.template.spec.containers[].image
```

### 6.5 Sync Windows (Maintenance Windows)

Control WHEN syncs are allowed — useful for blocking production deployments during business hours or peak traffic:

```yaml
# In AppProject spec
spec:
  syncWindows:
  # Allow manual syncs only on weekends
  - kind: allow
    schedule: "0 0 * * 6"           # Saturday midnight
    duration: 48h
    applications:
    - "*"
    manualSync: true

  # Block automated syncs on weekdays 9am-6pm
  - kind: deny
    schedule: "0 9 * * 1-5"         # Mon-Fri 9am
    duration: 9h
    applications:
    - "prod-*"
    manualSync: false
```

---

## 7. Rollback Procedures

### 7.1 Understanding ArgoCD History

ArgoCD maintains a history of all syncs. Each sync creates a new history entry with the Git revision (commit SHA) that was deployed.

```bash
# View deployment history (last 10 by default)
argocd app history frontend-dev

# Output:
# ID   DATE                           REVISION
# 0    2024-01-15 10:00:00 +0000 UTC  abc1234 (HEAD → main)
# 1    2024-01-15 09:00:00 UTC        def5678
# 2    2024-01-14 15:00:00 UTC        ghi9012
```

### 7.2 Rollback Methods

**Method 1: ArgoCD Rollback (to a previous sync)**

```bash
# Rollback to the previous deployment (history ID 1)
argocd app rollback frontend-dev 1

# This pins the app to that specific Git revision
# Auto-sync will be DISABLED after a rollback (by design)

# To re-enable auto-sync after rollback is verified
argocd app set frontend-dev --sync-policy automated
```

**Method 2: Git Revert (preferred GitOps way)**

```bash
# On your local machine
git log --oneline
# abc1234 (HEAD) feat: update frontend image to v2.0.0
# def5678 feat: update frontend image to v1.5.0
# ghi9012 feat: initial deployment

# Revert the bad commit
git revert abc1234
git push origin main

# ArgoCD will detect the new commit and auto-sync back to v1.5.0
# This is the PREFERRED method because it maintains audit trail
```

**Method 3: Git Reset + Force Push (emergency only)**

```bash
# WARNING: Rewrites history — use only in emergencies on non-production branches
git reset --hard def5678
git push --force origin main
```

### 7.3 Emergency Rollback Script

```bash
#!/bin/bash
# emergency-rollback.sh
# Usage: ./emergency-rollback.sh <app-name> <history-id>

APP_NAME=$1
HISTORY_ID=$2

echo "🚨 Emergency rollback initiated for: $APP_NAME to history: $HISTORY_ID"

# Disable auto-sync to prevent ArgoCD from overriding the rollback
argocd app set $APP_NAME --sync-policy none

# Perform rollback
argocd app rollback $APP_NAME $HISTORY_ID

# Wait for rollback to complete
argocd app wait $APP_NAME --health --timeout 300

# Check status
argocd app get $APP_NAME

echo "✅ Rollback complete. Auto-sync has been DISABLED."
echo "   Re-enable with: argocd app set $APP_NAME --sync-policy automated"
```

### 7.4 Rollback Verification Checklist

```bash
# 1. Check application health
argocd app get frontend-dev | grep -E "Health|Sync"

# 2. Verify pods are running
kubectl get pods -n frontend-dev

# 3. Check pod logs for errors
kubectl logs -l app=frontend -n frontend-dev --tail=50

# 4. Check events for issues
kubectl get events -n frontend-dev --sort-by='.lastTimestamp'

# 5. Verify the correct image version
kubectl get deployment frontend -n frontend-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 8. Health Checks & Status

### 8.1 ArgoCD Health Status States

| Status | Description | Action Needed |
|--------|-------------|---------------|
| `Healthy` | All resources are healthy and ready | None |
| `Progressing` | Resources are being created/updated (transitioning) | Wait |
| `Degraded` | One or more resources have failed | Investigate |
| `Missing` | Resources are defined in Git but don't exist in cluster | Sync |
| `Suspended` | A resource is intentionally paused (e.g., CronJob) | None |
| `Unknown` | ArgoCD cannot determine resource health | Check custom health checks |

### 8.2 Sync Status States

| Status | Description |
|--------|-------------|
| `Synced` | Cluster state matches Git (desired state) |
| `OutOfSync` | Cluster state differs from Git (drift detected) |
| `Unknown` | ArgoCD cannot compare (e.g., CRD not installed) |

### 8.3 Custom Health Checks

ArgoCD has built-in health checks for standard Kubernetes resources (Deployments, StatefulSets, Services, etc.). For custom resources, define your own:

```yaml
# argocd-cm ConfigMap — add custom health checks
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Custom health check for a CRD (using Lua)
  resource.customizations.health.myorg.io_MyCustomResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Running" then
        hs.status = "Healthy"
        hs.message = "Resource is running"
      elseif obj.status.phase == "Failed" then
        hs.status = "Degraded"
        hs.message = obj.status.message or "Resource failed"
      else
        hs.status = "Progressing"
        hs.message = "Resource is starting"
      end
    else
      hs.status = "Progressing"
      hs.message = "Waiting for status"
    end
    return hs
```

### 8.4 Health Check Commands

```bash
# Overall cluster health
argocd app list

# Detailed application health
argocd app get frontend-dev

# Watch health in real-time
watch -n 2 "argocd app get frontend-dev | grep -E 'Health|Sync|Message'"

# Get health of specific resource within an app
argocd app resources frontend-dev

# Show only unhealthy resources
argocd app resources frontend-dev --health=Degraded
```

### 8.5 Notifications for Health Events

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Slack notification template
  template.app-degraded: |
    slack:
      attachments: |
        [{
          "title": "🔴 Application Degraded: {{.app.metadata.name}}",
          "color": "#E53935",
          "fields": [
            { "title": "Environment", "value": "{{.app.metadata.labels.environment}}", "short": true },
            { "title": "Health", "value": "{{.app.status.health.status}}", "short": true },
            { "title": "Message", "value": "{{.app.status.health.message}}" }
          ]
        }]

  # Trigger: when health becomes Degraded
  trigger.on-degraded: |
    - description: Application is degraded
      send:
      - app-degraded
      when: app.status.health.status == 'Degraded'
```

---

## 9. Multi-Environment Setup (Dev / QA / Prod)

### 9.1 Environment Strategy

```
Git Branch Strategy (for environments):

Option A: Branch-per-Environment          Option B: Folder-per-Environment (Recommended)
─────────────────────────────             ────────────────────────────────────────────
main ────────────────────────             manifests/
  └── dev (auto-deploy)                   ├── frontend/
  └── qa  (auto-deploy)                   │   ├── base/          ← shared config
  └── prod (manual deploy)                │   ├── overlays/
                                          │   │   ├── dev/       ← dev-specific changes
                                          │   │   ├── qa/        ← qa-specific changes
                                          │   │   └── prod/      ← prod-specific changes
```

**Folder-per-environment is recommended** because:
- No branch merge conflicts
- Single commit updates all envs or specific envs
- Cleaner promotion workflow

### 9.2 ArgoCD Project per Environment

```yaml
# projects/dev-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: dev-project
  namespace: argocd
spec:
  description: Development environment project

  # Allowed source repositories
  sourceRepos:
  - "https://github.com/your-org/my-gitops-repo.git"
  - "https://charts.helm.sh/stable"

  # Allowed destination clusters and namespaces
  destinations:
  - namespace: "dev-*"
    server: https://kubernetes.default.svc

  # Cluster-scoped resource whitelist (empty = deny all cluster resources)
  clusterResourceWhitelist:
  - group: ""
    kind: Namespace                # Allow creating namespaces

  # Namespace-scoped resource blacklist (block dangerous operations)
  namespaceResourceBlacklist:
  - group: ""
    kind: ResourceQuota            # Dev team cannot modify quotas

  # Roles within this project
  roles:
  - name: dev-deploy
    description: Developers can deploy to dev
    policies:
    - p, proj:dev-project:dev-deploy, applications, sync, dev-project/*, allow
    - p, proj:dev-project:dev-deploy, applications, get, dev-project/*, allow
    groups:
    - dev-team

---
# projects/prod-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: prod-project
  namespace: argocd
spec:
  description: Production environment — manual syncs only

  sourceRepos:
  - "https://github.com/your-org/my-gitops-repo.git"

  destinations:
  - namespace: "prod-*"
    server: https://kubernetes.default.svc

  clusterResourceWhitelist:
  - group: ""
    kind: Namespace

  # Restrict sync windows for production
  syncWindows:
  - kind: allow
    schedule: "0 2 * * 2,4"        # Allow only Tue/Thu at 2am
    duration: 2h
    applications:
    - "*"
    manualSync: true               # Manual sync still allowed anytime
```

### 9.3 Per-Environment Application Manifests

```yaml
# apps/dev/app-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-dev
  namespace: argocd
spec:
  project: dev-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: kustomize/overlays/dev             # dev-specific Kustomize overlay
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true                         # Auto-heal in dev
    syncOptions:
    - CreateNamespace=true

---
# apps/qa/app-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-qa
  namespace: argocd
spec:
  project: qa-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: kustomize/overlays/qa
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-qa
  syncPolicy:
    automated:
      prune: true
      selfHeal: false                        # Don't auto-heal in QA (for testing)

---
# apps/prod/app-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-prod
  namespace: argocd
spec:
  project: prod-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: v1.5.0                   # Pin to a specific Git tag in prod
    path: kustomize/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-prod
  syncPolicy:
    # NO automated sync in production — manual only
    syncOptions:
    - CreateNamespace=true
    - PruneLast=true
```

### 9.4 Promotion Workflow

```
Developer Workflow (GitOps Promotion):

1. Developer merges PR to main
        │
        ▼
2. CI Pipeline builds image → tags as :dev-abc1234
        │
        ▼
3. CI updates kustomize/overlays/dev/kustomization.yaml
   (newTag: dev-abc1234)
        │
        ▼
4. ArgoCD auto-syncs → deploys to DEV namespace
        │
        ▼ (after QA testing passes)
5. PR: update kustomize/overlays/qa/kustomization.yaml
   (newTag: dev-abc1234 → tested image)
        │
        ▼
6. ArgoCD auto-syncs → deploys to QA namespace
        │
        ▼ (after QA sign-off)
7. PR: update kustomize/overlays/prod/kustomization.yaml
   (newTag: v1.5.0 — final production image tag)
        │
        ▼
8. Manual argocd app sync frontend-prod
```

---

## 10. Helm Integration

### 10.1 Using Helm Charts from a Registry

```yaml
# Deploy Nginx Ingress Controller from Helm chart
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx    # Helm chart repo
    chart: ingress-nginx                                   # Chart name
    targetRevision: 4.8.3                                  # Chart version (pin this!)
    helm:
      releaseName: nginx-ingress                           # Helm release name
      values: |
        controller:
          replicaCount: 2
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
          service:
            type: LoadBalancer
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 10.2 Using Helm Charts from Git

```yaml
# Your chart is in your own Git repo
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: dev-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: helm/myapp                                       # Path to Chart.yaml
    helm:
      releaseName: myapp
      valueFiles:
      - values.yaml                                        # Base values
      - values-dev.yaml                                    # Environment override
      values: |
        image:
          tag: "abc1234"                                   # Dynamic override from CI
      parameters:
      - name: replicaCount
        value: "2"
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp-dev
```

### 10.3 Example Helm Chart Structure

```yaml
# helm/myapp/Chart.yaml
apiVersion: v2
name: myapp
description: My Application Helm Chart
type: application
version: 0.1.0
appVersion: "1.0.0"

---
# helm/myapp/values.yaml (base values)
replicaCount: 1
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

---
# helm/myapp/values-dev.yaml (dev overrides)
replicaCount: 1
image:
  tag: "dev-latest"
resources:
  limits:
    cpu: 100m
    memory: 128Mi

---
# helm/myapp/values-prod.yaml (prod overrides)
replicaCount: 3
image:
  tag: "v1.5.0"
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

```yaml
# helm/myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: 80
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

### 10.4 Helm Hooks with ArgoCD

```yaml
# Use Helm hooks for pre/post deploy jobs
# templates/pre-upgrade-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-pre-upgrade"
  annotations:
    "helm.sh/hook": pre-upgrade                 # Helm pre-upgrade hook
    "helm.sh/hook-weight": "-5"                 # Run before other pre-upgrade hooks
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migration
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        command: ["./migrate.sh"]
```

---

## 11. Kustomize Integration

### 11.1 Kustomize Concepts

Kustomize uses a `base` (shared configuration) + `overlays` (environment-specific patches) model. Unlike Helm, it requires no templating — just plain YAML + patches.

### 11.2 Base Configuration

```yaml
# kustomize/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

# Common labels applied to ALL resources
commonLabels:
  app: myapp
  managed-by: argocd

# Common annotations
commonAnnotations:
  contact: "platform-team@company.com"
```

```yaml
# kustomize/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest                    # Kustomize will update this image tag
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
```

### 11.3 Dev Overlay

```yaml
# kustomize/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp-dev

bases:
- ../../base

# Override the image tag
images:
- name: myapp
  newTag: dev-abc1234                          # Updated by CI pipeline

# Patch: override replica count
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
  target:
    kind: Deployment
    name: myapp

# Add dev-specific ConfigMap values
configMapGenerator:
- name: myapp-config
  literals:
  - ENV=development
  - LOG_LEVEL=debug
  - DB_HOST=dev-postgres.myapp-dev.svc
```

### 11.4 Production Overlay

```yaml
# kustomize/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp-prod

bases:
- ../../base

images:
- name: myapp
  newTag: v1.5.0                               # Pinned production tag

# Strategic merge patch for replicas and resources
patches:
- path: patch-deployment.yaml
  target:
    kind: Deployment

configMapGenerator:
- name: myapp-config
  literals:
  - ENV=production
  - LOG_LEVEL=warn
  - DB_HOST=prod-postgres.myapp-prod.svc

# Add HPA for production
resources:
- hpa.yaml
- poddisruptionbudget.yaml
```

```yaml
# kustomize/overlays/prod/patch-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3                                  # 3 replicas in prod
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### 11.5 ArgoCD Application with Kustomize

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  namespace: argocd
spec:
  project: prod-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: kustomize/overlays/prod
    kustomize:
      version: v5.0.0                          # Pin kustomize version
      images:
      - myapp=registry.company.com/myapp:v1.5.0  # Override image at deploy time
      commonLabels:
        deploy-timestamp: "2024-01-15"
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp-prod
```

### 11.6 Test Kustomize Output Locally

```bash
# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Preview what ArgoCD will deploy (dry run)
kustomize build kustomize/overlays/dev
kustomize build kustomize/overlays/prod

# Diff between environments
diff \
  <(kustomize build kustomize/overlays/dev) \
  <(kustomize build kustomize/overlays/prod)
```

---

## 12. RBAC Configuration

### 12.1 ArgoCD RBAC Model

ArgoCD uses a two-level RBAC system:
1. **Project-level RBAC** (`AppProject.spec.roles`) — controls access to applications within a project
2. **Global RBAC** (`argocd-rbac-cm` ConfigMap) — defines global policies and role mappings

### 12.2 Built-in Roles

| Role | Permissions |
|------|-------------|
| `role:admin` | Full access to everything |
| `role:readonly` | Read-only access to everything |

### 12.3 Global RBAC Configuration

```yaml
# argocd-rbac-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly              # Default role for authenticated users

  policy.csv: |
    # Format: p, <role>, <resource>, <action>, <appproject/application>, <effect>
    # Resources: applications, applicationsets, clusters, repositories, projects, accounts, certificates, gpgkeys, logs, exec
    # Actions: get, create, update, delete, sync, override, action

    # Admin role (full access)
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, logs, get, */*, allow
    p, role:admin, exec, create, */*, allow

    # Developer role (can sync dev apps, read QA, no prod)
    p, role:developer, applications, get, dev-project/*, allow
    p, role:developer, applications, sync, dev-project/*, allow
    p, role:developer, applications, get, qa-project/*, allow
    p, role:developer, logs, get, dev-project/*, allow

    # QA role (can sync QA apps)
    p, role:qa, applications, get, qa-project/*, allow
    p, role:qa, applications, sync, qa-project/*, allow
    p, role:qa, logs, get, qa-project/*, allow

    # Release manager (can sync production with manual gate)
    p, role:release-manager, applications, get, */*, allow
    p, role:release-manager, applications, sync, prod-project/*, allow
    p, role:release-manager, applications, override, prod-project/*, allow

    # Map SSO groups to ArgoCD roles
    g, github-org:dev-team, role:developer
    g, github-org:qa-team, role:qa
    g, github-org:release-team, role:release-manager
    g, github-org:platform-team, role:admin

    # Map local users to roles
    g, dev-user1, role:developer
    g, admin-user, role:admin
```

### 12.4 Create Local Users

```yaml
# argocd-cm ConfigMap — add local users
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  accounts.dev-user1: apiKey, login        # apiKey = can create tokens; login = can login to UI
  accounts.ci-robot: apiKey                # CI robot — API key only (no UI login)
  accounts.readonly-user: login            # Read-only user
```

```bash
# Set passwords for local users
argocd account update-password \
  --account dev-user1 \
  --new-password <strong-password>

# Create API key for CI robot
argocd account generate-token --account ci-robot
# Save this token securely — use it in CI pipelines

# List all accounts
argocd account list
```

### 12.5 SSO Integration (GitHub Example)

```yaml
# argocd-cm ConfigMap — Dex OIDC with GitHub
data:
  url: https://argocd.company.com
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: <github-oauth-app-client-id>
        clientSecret: $dex.github.clientSecret  # Reference to secret
        redirectURI: https://argocd.company.com/api/dex/callback
        orgs:
        - name: your-github-org
          teams:
          - dev-team
          - qa-team
          - release-team
          - platform-team
```

---

## 13. Secrets Management

### 13.1 The Problem with Secrets in GitOps

You should NEVER commit plaintext secrets to Git. ArgoCD needs to deploy secrets to Kubernetes, but the secret values themselves must be managed securely.

```
Bad approach (NEVER do this):
─────────────────────────────
# secrets.yaml in Git repo ❌
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
data:
  password: bXlwYXNzd29yZA==    # base64("mypassword") — STILL READABLE!
```

### 13.2 Approach 1: Bitnami Sealed Secrets (Recommended for simplicity)

Sealed Secrets encrypts secrets using a cluster-specific key. Only your cluster can decrypt them.

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml

# Install kubeseal CLI
curl -sSL https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/kubeseal-linux-amd64 \
  -o kubeseal
chmod +x kubeseal && sudo mv kubeseal /usr/local/bin/
```

```bash
# Create a regular Kubernetes secret (NOT committed to Git)
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client \
  -o yaml > /tmp/db-secret.yaml

# Seal it (output is safe to commit to Git)
kubeseal --format=yaml < /tmp/db-secret.yaml > manifests/secrets/db-secret-sealed.yaml

# The sealed secret can be committed to Git safely
cat manifests/secrets/db-secret-sealed.yaml
# apiVersion: bitnami.com/v1alpha1
# kind: SealedSecret
# ...
# spec:
#   encryptedData:
#     password: AgBv7...  # Encrypted — safe to commit!
```

```yaml
# manifests/secrets/db-secret-sealed.yaml (commit this to Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-secret
  namespace: myapp-prod
spec:
  encryptedData:
    username: AgBy...    # Encrypted with cluster public key
    password: AgBv7...   # Only THIS cluster can decrypt
  template:
    metadata:
      name: db-secret
    type: Opaque
```

### 13.3 Approach 2: ArgoCD Vault Plugin (AVP) — Enterprise Standard

ArgoCD Vault Plugin integrates with HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault. Secrets are fetched at deploy time — never stored in Git.

```yaml
# Install ArgoCD Vault Plugin as a custom plugin
# argocd-cm ConfigMap
data:
  configManagementPlugins: |
    - name: argocd-vault-plugin
      generate:
        command: ["argocd-vault-plugin"]
        args: ["generate", "./"]
```

```yaml
# manifests/backend/deployment.yaml (with AVP placeholders)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  annotations:
    avp.kubernetes.io/path: "secret/data/myapp/prod"  # Vault path
spec:
  template:
    spec:
      containers:
      - name: backend
        env:
        - name: DB_PASSWORD
          value: <db-password>          # AVP replaces this with value from Vault
        - name: API_KEY
          value: <api-key>              # AVP replaces this at sync time
```

### 13.4 Approach 3: External Secrets Operator (ESO)

ESO syncs secrets from AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, HashiCorp Vault into Kubernetes Secrets automatically.

```yaml
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace

# Create a SecretStore (connects to your secret backend)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: myapp-prod
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-creds
            key: access-key
          secretAccessKeySecretRef:
            name: aws-creds
            key: secret-key

---
# Create an ExternalSecret (define what to pull)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: myapp-prod
spec:
  refreshInterval: 1h                   # How often to sync from external source
  secretStoreRef:
    kind: SecretStore
    name: aws-secretsmanager
  target:
    name: db-secret                     # Creates this Kubernetes Secret
    creationPolicy: Owner
  data:
  - secretKey: password                 # Key in Kubernetes Secret
    remoteRef:
      key: myapp/prod/db-credentials    # Key in AWS Secrets Manager
      property: password                # Field within the secret
```

---

## 14. CI/CD Integration

### 14.1 GitOps CI/CD Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitOps CI/CD Pipeline                        │
│                                                                  │
│  Code Repo              Config Repo              Kubernetes       │
│  ─────────              ───────────              ──────────       │
│  git push               git push                                  │
│      │                      │                      │             │
│      ▼                      │                      │             │
│  CI Pipeline                │                      │             │
│  ├─ Run tests               │                      │             │
│  ├─ Build image             │                      │             │
│  ├─ Push to registry        │                      │             │
│  └─ Update config repo ─────►                      │             │
│     (image tag update)      │                      │             │
│                             ▼                      │             │
│                        ArgoCD detects              │             │
│                        new commit                  │             │
│                             │                      │             │
│                             └─────── Syncs ────────►             │
│                                     to cluster                   │
└─────────────────────────────────────────────────────────────────┘
```

### 14.2 GitHub Actions Integration

```yaml
# .github/workflows/deploy.yaml
name: Build and Deploy

on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      short-sha: ${{ steps.short-sha.outputs.sha }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Get short SHA
      id: short-sha
      run: echo "sha=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.short-sha.outputs.sha }}

  update-gitops-config:
    needs: build-and-push
    runs-on: ubuntu-latest

    steps:
    - name: Checkout GitOps config repo
      uses: actions/checkout@v4
      with:
        repository: your-org/my-gitops-repo
        token: ${{ secrets.GITOPS_PAT }}         # PAT with repo write access
        path: gitops-repo

    - name: Update image tag in Kustomize
      run: |
        cd gitops-repo
        # Use kustomize to update image tag
        cd kustomize/overlays/dev
        kustomize edit set image \
          myapp=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build-and-push.outputs.short-sha }}

    - name: Commit and push
      run: |
        cd gitops-repo
        git config user.name "GitHub Actions Bot"
        git config user.email "bot@github.com"
        git add .
        git diff --staged --quiet || \
          git commit -m "ci: update dev image to ${{ needs.build-and-push.outputs.short-sha }}"
        git push

  # Optional: Trigger ArgoCD sync via API (if auto-sync is disabled)
  trigger-argocd-sync:
    needs: update-gitops-config
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Sync ArgoCD Application
      run: |
        argocd app sync myapp-dev \
          --auth-token ${{ secrets.ARGOCD_TOKEN }} \
          --server ${{ secrets.ARGOCD_SERVER }} \
          --insecure \
          --force

    - name: Wait for ArgoCD sync
      run: |
        argocd app wait myapp-dev \
          --auth-token ${{ secrets.ARGOCD_TOKEN }} \
          --server ${{ secrets.ARGOCD_SERVER }} \
          --insecure \
          --health \
          --timeout 300
```

### 14.3 GitLab CI Integration

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - update-config
  - deploy

variables:
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$IMAGE_TAG .
    - docker push $CI_REGISTRY_IMAGE:$IMAGE_TAG

update-gitops-config:
  stage: update-config
  image: alpine/git:latest
  script:
    - git clone https://oauth2:$GITOPS_TOKEN@gitlab.com/your-org/my-gitops-repo.git
    - cd my-gitops-repo
    - apk add --no-cache curl
    - curl -sSL https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_linux_amd64.tar.gz | tar xz
    - ./kustomize edit set image myapp=$CI_REGISTRY_IMAGE:$IMAGE_TAG
      --kustomization kustomize/overlays/dev/kustomization.yaml
    - git config user.email "gitlab-ci@company.com"
    - git config user.name "GitLab CI"
    - git add .
    - git diff --staged --quiet || git commit -m "ci: update dev to $IMAGE_TAG"
    - git push
  only:
    - main
```

### 14.4 Argo CD Image Updater (Automatic Image Updates)

Instead of having CI update the GitOps repo, Image Updater can do it automatically:

```yaml
# Install
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Configure on an Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  annotations:
    # Watch this image for updates
    argocd-image-updater.argoproj.io/image-list: myapp=ghcr.io/your-org/myapp
    # Update strategy: semver, latest, digest, name
    argocd-image-updater.argoproj.io/myapp.update-strategy: latest
    # Write the update back to Git (GitOps way)
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: kustomization
    # Filter to only use dev-* tagged images
    argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^dev-
```

---

## 15. Monitoring & Troubleshooting

### 15.1 ArgoCD Metrics (Prometheus Integration)

```bash
# Check ArgoCD exposes metrics
kubectl get svc -n argocd | grep metrics
# argocd-application-controller-metrics   ClusterIP   80/TCP
# argocd-server-metrics                   ClusterIP   8083/TCP
# argocd-repo-server                      ClusterIP   8084/TCP
```

```yaml
# ServiceMonitor for Prometheus (if using Prometheus Operator)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
  namespaceSelector:
    matchNames:
    - argocd
```

**Key Prometheus Metrics:**

| Metric | Description |
|--------|-------------|
| `argocd_app_info` | Application metadata (name, namespace, health, sync status) |
| `argocd_app_sync_total` | Total number of syncs by result (succeeded/failed) |
| `argocd_app_k8s_request_total` | Kubernetes API requests made by app controller |
| `argocd_cluster_api_resource_objects` | Total number of managed resources per cluster |
| `argocd_git_request_total` | Git operations (ls-remote, fetch) by result |
| `argocd_git_request_duration_seconds` | Git operation latency |

### 15.2 Grafana Dashboard

Import the official ArgoCD Grafana dashboard using ID: `14584`

```bash
# Port-forward Grafana (if installed)
kubectl port-forward svc/grafana -n monitoring 3000:80

# Import dashboard ID: 14584 from grafana.com
# Or add via ConfigMap if using Grafana Operator
```

### 15.3 Essential Troubleshooting Commands

```bash
# === Application Issues ===

# Get full application details
argocd app get <app-name> --show-params --show-operation

# See diff between Git (desired) and cluster (actual)
argocd app diff <app-name>

# See diff with a specific revision
argocd app diff <app-name> --revision abc1234

# Get logs from ArgoCD components
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 -f
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100 -f
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100 -f

# === Sync Issues ===

# Force a hard refresh (bypass cache, re-fetch from Git)
argocd app get <app-name> --hard-refresh

# Sync with force (replace conflicting resources)
argocd app sync <app-name> --force

# Sync only a specific resource
argocd app sync <app-name> --resource apps:Deployment:frontend

# Sync with dry-run (preview changes)
argocd app sync <app-name> --dry-run

# === Repository Issues ===

# Test repository connectivity
argocd repo get https://github.com/your-org/my-gitops-repo.git

# Refresh repository (force re-clone)
argocd repo refresh https://github.com/your-org/my-gitops-repo.git

# === Resource Specific ===

# List all resources managed by an app
argocd app resources <app-name>

# Exec into a pod (if exec is enabled)
argocd app exec <app-name> -- bash
```

### 15.4 Common Issues & Fixes

**Issue: OutOfSync but nothing looks different**
```bash
# Check for annotations/labels added by other controllers
argocd app diff <app-name>

# Common causes: resource versions, last-applied-configuration annotations
# Fix: Add ignoreDifferences to the Application spec (see Section 6.4)
```

**Issue: Sync stuck in "Progressing"**
```bash
# Check what resource is blocking
argocd app resources <app-name> | grep Progressing

# Check the resource's events
kubectl describe deployment <deployment-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

**Issue: Repository permission denied**
```bash
# Check repo credentials are stored correctly
argocd repo list

# Re-add with correct credentials
argocd repo add https://github.com/org/repo.git \
  --username <user> \
  --password <token>
```

**Issue: Webhook not triggering sync**
```bash
# Check ArgoCD webhook logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server | grep webhook

# Verify webhook secret matches
kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.webhook\.github\.secret}' | base64 -d
```

**Issue: Application stuck after failed sync**
```bash
# Terminate the current operation
argocd app terminate-op <app-name>

# Then retry sync
argocd app sync <app-name>
```

### 15.5 Audit Log

```bash
# ArgoCD logs all operations — check them for audit
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-server \
  --since=1h | grep -E "sync|delete|create|update" | jq .
```

---

## 16. Real-World Production Use Cases

### 16.1 Progressive Delivery with Argo Rollouts

Argo Rollouts extends ArgoCD with advanced deployment strategies (Canary, Blue/Green) instead of basic Rolling Updates.

```yaml
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f \
  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Canary Deployment: send 10% → 50% → 100% traffic gradually
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: frontend
  namespace: frontend-prod
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10              # Send 10% to new version
      - pause:
          duration: 5m             # Wait 5 minutes, observe metrics
      - setWeight: 50              # Send 50%
      - pause:
          duration: 10m            # Wait 10 minutes
      - setWeight: 100             # Full rollout

      # Automatic analysis — rollback if error rate spikes
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 1
        args:
        - name: service-name
          value: frontend-svc-canary

  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.25.3
```

```yaml
# AnalysisTemplate: Automatically rollback if error rate > 5%
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 5m
    successCondition: result[0] >= 0.95     # 95% success rate required
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.."}[5m]))
          /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

### 16.2 Multi-Cluster Management

```yaml
# Register a remote cluster (e.g., production cluster)
argocd cluster add <context-name-from-kubeconfig>

# List registered clusters
argocd cluster list

# Application targeting remote cluster
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod
  namespace: argocd
spec:
  project: prod-project
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: v1.5.0
    path: kustomize/overlays/prod
  destination:
    server: https://prod-cluster.company.com:6443  # Remote cluster URL
    namespace: myapp-prod
```

### 16.3 ApplicationSet for Dynamic Application Generation

ApplicationSet generates ArgoCD Applications dynamically from templates. Perfect for managing many environments or clusters.

```yaml
# Generate one app per cluster using List Generator
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-all-clusters
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev-cluster.company.com:6443
        namespace: myapp-dev
        values:
          replicas: "1"
      - cluster: qa
        url: https://qa-cluster.company.com:6443
        namespace: myapp-qa
        values:
          replicas: "2"
      - cluster: prod
        url: https://prod-cluster.company.com:6443
        namespace: myapp-prod
        values:
          replicas: "5"

  template:
    metadata:
      name: "myapp-{{cluster}}"                    # Dynamic name
    spec:
      project: "{{cluster}}-project"
      source:
        repoURL: https://github.com/your-org/my-gitops-repo.git
        targetRevision: HEAD
        path: kustomize/overlays/{{cluster}}
        kustomize:
          patches:
          - target:
              kind: Deployment
            patch: |-
              - op: replace
                path: /spec/replicas
                value: {{values.replicas}}
      destination:
        server: "{{url}}"
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true

---
# Git Generator: create one app per directory in Git
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
spec:
  generators:
  - git:
      repoURL: https://github.com/your-org/my-gitops-repo.git
      revision: HEAD
      directories:
      - path: "cluster-addons/*"           # One app per subdirectory
  template:
    metadata:
      name: "addon-{{path.basename}}"
    spec:
      project: platform
      source:
        repoURL: https://github.com/your-org/my-gitops-repo.git
        targetRevision: HEAD
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "addon-{{path.basename}}"
```

### 16.4 Disaster Recovery with ArgoCD

```bash
# BACKUP: Export all ArgoCD resources (applications, projects, settings)
kubectl get applications,appprojects -n argocd -o yaml > argocd-backup-$(date +%Y%m%d).yaml

# DR Scenario: Cluster completely lost
# 1. Install ArgoCD on new cluster
# 2. Restore from backup
kubectl apply -f argocd-backup-20240115.yaml

# 3. Re-register Git repositories
argocd repo add https://github.com/your-org/my-gitops-repo.git

# 4. Sync all applications from Git (Git IS the source of truth)
argocd app sync --selector "managed-by=argocd" --all

# Because Git has ALL the desired state, full cluster recovery is just:
# install ArgoCD + point it at Git = cluster restored
```

---

## 17. Hands-On Labs & Project Exercises

### Lab 1: Deploy a Multi-Tier Application (Beginner)

**Objective:** Deploy a frontend + backend + database application using ArgoCD and raw Kubernetes manifests.

```bash
# Step 1: Create the manifests
mkdir -p labs/lab1/{frontend,backend,database}

# Database (PostgreSQL)
cat > labs/lab1/database/statefulset.yaml <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: lab1
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: appdb
        - name: POSTGRES_USER
          value: appuser
        - name: POSTGRES_PASSWORD
          value: changeme          # In real scenarios, use Sealed Secrets
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

# Backend API
cat > labs/lab1/backend/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: lab1
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: kennethreitz/httpbin:latest
        ports:
        - containerPort: 80
EOF

# Frontend
cat > labs/lab1/frontend/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: lab1
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Step 2: Commit and push
git add labs/lab1/ && git commit -m "lab1: add multi-tier app manifests" && git push

# Step 3: Create ArgoCD Application
argocd app create lab1 \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path labs/lab1 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace lab1 \
  --sync-option CreateNamespace=true \
  --sync-policy automated

# Step 4: Watch the deployment waves (DB → Backend → Frontend)
watch -n 1 "argocd app resources lab1"
```

**✅ Lab 1 Success Criteria:**
- All pods in `lab1` namespace are Running
- Sync waves deployed in order: postgres (wave 0) → backend (wave 1) → frontend (wave 2)
- `argocd app get lab1` shows `Health: Healthy` and `Sync: Synced`

---

### Lab 2: GitOps Update & Rollback (Intermediate)

**Objective:** Practice image updates via Git commits and rollbacks.

```bash
# Step 1: Note current deployed version
kubectl get deployment frontend -n lab1 \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# nginx:alpine

# Step 2: Update the image in Git (simulating a new release)
sed -i 's/nginx:alpine/nginx:1.25.3-alpine/g' labs/lab1/frontend/deployment.yaml
git add . && git commit -m "feat: update frontend to nginx 1.25.3" && git push

# Step 3: Watch ArgoCD auto-sync the change
watch -n 2 "kubectl get pods -n lab1"

# Step 4: Verify new version is deployed
kubectl get deployment frontend -n lab1 \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# nginx:1.25.3-alpine ✓

# Step 5: Simulate a bad deployment
sed -i 's/nginx:1.25.3-alpine/nginx:BROKEN_TAG/g' labs/lab1/frontend/deployment.yaml
git add . && git commit -m "bug: bad image tag" && git push

# Step 6: Observe the degraded health
watch -n 2 "argocd app get lab1 | grep -E 'Health|Message'"
kubectl get pods -n lab1    # See ImagePullBackOff

# Step 7: Rollback via Git revert (recommended)
git revert HEAD --no-edit
git push

# ArgoCD auto-syncs and nginx:1.25.3-alpine is restored

# Step 8: Verify recovery
argocd app wait lab1 --health --timeout 120
kubectl get pods -n lab1
```

**✅ Lab 2 Success Criteria:**
- Successful GitOps update via Git commit
- Observed automatic sync by ArgoCD
- Successful rollback via `git revert` (NOT `argocd app rollback`)

---

### Lab 3: Kustomize Multi-Environment (Intermediate)

**Objective:** Deploy the same application to dev and prod namespaces using Kustomize overlays.

```bash
# Create Kustomize structure
mkdir -p labs/lab3/{base,overlays/{dev,prod}}

# Base
cat > labs/lab3/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
commonLabels:
  app: lab3-app
EOF

cat > labs/lab3/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lab3-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lab3-app
  template:
    metadata:
      labels:
        app: lab3-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# Dev overlay (1 replica, debug logging)
cat > labs/lab3/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: lab3-dev
bases:
- ../../base
images:
- name: nginx
  newTag: alpine
configMapGenerator:
- name: lab3-config
  literals:
  - ENV=dev
  - LOG_LEVEL=debug
EOF

# Prod overlay (3 replicas, warning logging)
cat > labs/lab3/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: lab3-prod
bases:
- ../../base
images:
- name: nginx
  newTag: 1.25.3-alpine
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
configMapGenerator:
- name: lab3-config
  literals:
  - ENV=production
  - LOG_LEVEL=warn
EOF

# Commit
git add labs/lab3/ && git commit -m "lab3: kustomize multi-env setup" && git push

# Deploy both environments
argocd app create lab3-dev \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path labs/lab3/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace lab3-dev \
  --sync-option CreateNamespace=true \
  --sync-policy automated

argocd app create lab3-prod \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path labs/lab3/overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace lab3-prod \
  --sync-option CreateNamespace=true

# Compare what was deployed
kubectl get deployment -n lab3-dev lab3-app -o jsonpath='{.spec.replicas}'   # 1
kubectl get deployment -n lab3-prod lab3-app -o jsonpath='{.spec.replicas}'  # 3
```

---

### Lab 4: Sync Hooks & Waves (Advanced)

**Objective:** Use PreSync hooks and sync waves for ordered, safe deployments.

```bash
mkdir -p labs/lab4

# PreSync: DB Schema migration job
cat > labs/lab4/00-presync-migration.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: schema-migration
  namespace: lab4
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: busybox
        command: [sh, -c, "echo 'Running DB migration...'; sleep 5; echo 'Migration complete!'"]
EOF

# Wave 0: Database
cat > labs/lab4/01-database.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: lab4
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: redis:7-alpine
        ports:
        - containerPort: 6379
EOF

# Wave 1: Backend (waits for wave 0)
cat > labs/lab4/02-backend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: lab4
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
EOF

# Wave 2: Frontend (waits for wave 1)
cat > labs/lab4/03-frontend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: lab4
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
EOF

# PostSync: Smoke test
cat > labs/lab4/04-postsync-test.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  namespace: lab4
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: test
        image: busybox
        command: [sh, -c, "echo 'Running smoke tests...'; sleep 3; echo 'All tests passed!'"]
EOF

git add labs/lab4/ && git commit -m "lab4: sync hooks and waves demo" && git push

argocd app create lab4 \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path labs/lab4 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace lab4 \
  --sync-option CreateNamespace=true

# Trigger sync and watch the phases
argocd app sync lab4
kubectl get jobs -n lab4 -w    # Watch PreSync → PostSync hooks
```

---

### Lab 5: RBAC & Project Setup (Advanced)

**Objective:** Create an AppProject with RBAC, restricting deployments to specific namespaces.

```bash
# Create the AppProject
cat > projects/lab5-project.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: lab5-project
  namespace: argocd
spec:
  description: "Lab 5 RBAC Demo Project"
  sourceRepos:
  - "https://github.com/<your-username>/my-gitops-repo.git"
  destinations:
  - namespace: "lab5-*"
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ""
    kind: Namespace
  roles:
  - name: deployer
    description: Can deploy to lab5 namespaces
    policies:
    - p, proj:lab5-project:deployer, applications, sync, lab5-project/*, allow
    - p, proj:lab5-project:deployer, applications, get, lab5-project/*, allow
EOF

kubectl apply -f projects/lab5-project.yaml

# Verify the project was created
argocd proj get lab5-project

# Try to create an app in a namespace NOT allowed by the project
argocd app create lab5-test \
  --project lab5-project \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path labs/lab1 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kube-system    # This SHOULD FAIL — kube-system not in allowed destinations

# Expected: error — application destination server/namespace not permitted
```

---

### Final Project: Complete End-to-End GitOps Pipeline

**Objective:** Build a production-like GitOps pipeline for a microservices application with:
- 3 services (frontend, backend, database)
- 2 environments (dev, prod)
- Kustomize overlays
- RBAC project separation
- Sync hooks for ordered deployment
- GitHub Actions CI for image updates
- Sealed Secrets for sensitive data
- Rollback demonstration

**Architecture:**

```
GitHub Repo (code) ──CI Build──► Container Registry
                                        │
                                        ▼
GitHub Repo (config) ◄──── CI updates image tag
         │
         │ ArgoCD watches
         ▼
  ┌──────────────────────────┐
  │      ArgoCD              │
  │  ┌────────┐ ┌──────────┐ │
  │  │dev-app │ │prod-app  │ │
  │  └────────┘ └──────────┘ │
  └──────────────────────────┘
         │           │
         ▼           ▼
    dev namespace  prod namespace
    (auto-sync)    (manual sync)
```

**Implementation Steps:**

```bash
# 1. Create project structure
mkdir -p final-project/{apps/{dev,prod},kustomize/{base,overlays/{dev,prod}},
  manifests,projects,sealed-secrets,.github/workflows}

# 2. Create AppProjects
# final-project/projects/dev-project.yaml  (see Section 9.2)
# final-project/projects/prod-project.yaml (see Section 9.2)

# 3. Create base Kustomize manifests
# final-project/kustomize/base/ (see Section 11.2)

# 4. Create dev and prod overlays
# final-project/kustomize/overlays/dev/  (see Section 11.3)
# final-project/kustomize/overlays/prod/ (see Section 11.4)

# 5. Create ArgoCD Applications
# final-project/apps/dev/app.yaml   (auto-sync)
# final-project/apps/prod/app.yaml  (manual sync, pinned to tag)

# 6. Set up GitHub Actions CI
# final-project/.github/workflows/deploy.yaml (see Section 14.2)

# 7. Add Sealed Secrets for DB credentials
# final-project/sealed-secrets/db-secret.yaml (see Section 13.2)

# 8. Deploy root App of Apps
argocd app create final-project-root \
  --repo https://github.com/<your-username>/my-gitops-repo.git \
  --path final-project/apps/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated

# 9. Verify full pipeline:
# a) Push code change → CI builds new image
# b) CI updates kustomization.yaml image tag
# c) ArgoCD detects change, auto-syncs dev
# d) Verify dev deployment
# e) Update prod overlay with tested tag
# f) Manual sync prod
# g) Verify prod deployment
```

---

## 18. Best Practices Cheat Sheet

### GitOps & Repository

| ✅ Do | ❌ Don't |
|-------|---------|
| Keep Git as the single source of truth | Use `kubectl apply` directly in production |
| Use Git tags for production releases | Use `latest` image tags in production |
| Pin Helm chart versions | Use floating versions (`>=1.0.0`) |
| Use branch protection on main | Allow direct pushes to main |
| Review all config changes via PR | Merge without review |
| Store secrets using Sealed Secrets / ESO | Commit plaintext secrets to Git |
| Use meaningful commit messages | Use vague commit messages like "update" |

### ArgoCD Configuration

| ✅ Do | ❌ Don't |
|-------|---------|
| Enable `selfHeal` in dev, consider carefully in prod | Enable `selfHeal` without understanding the implications |
| Use `PruneLast=true` in production | Prune resources recklessly |
| Set `finalizers` on Applications | Delete apps without cleanup |
| Pin `targetRevision` to a tag in production | Use `HEAD` in production |
| Use AppProjects to isolate environments | Deploy everything under `default` project |
| Set resource limits via RBAC | Allow unrestricted resource creation |
| Use sync waves for dependent services | Assume services deploy in order |
| Configure `retry.limit` for transient failures | Leave retry as unlimited |

### Security

| ✅ Do | ❌ Don't |
|-------|---------|
| Enable SSO/OIDC for authentication | Use the admin password in automation |
| Create dedicated service accounts for CI | Share credentials between teams |
| Use project-level RBAC to limit access | Give everyone admin access |
| Rotate ArgoCD API tokens regularly | Use non-expiring tokens |
| Enable audit logging | Run ArgoCD without logs |
| Use network policies to restrict ArgoCD traffic | Expose ArgoCD API to the public internet without auth |

### Operational

| ✅ Do | ❌ Don't |
|-------|---------|
| Monitor `argocd_app_info` metrics | Ignore sync failure alerts |
| Set up Slack/PagerDuty notifications | Wait for users to report issues |
| Test rollback procedures regularly | Assume rollback will work when needed |
| Back up ArgoCD Application CRDs | Rely solely on in-cluster state |
| Use `--dry-run` before syncing production | Sync production without preview |
| Document your GitOps workflow in the repo | Leave the team guessing |

---

## Quick Reference Card

```bash
# ═══════════════════════════════════════════════════
#              ArgoCD Quick Reference
# ═══════════════════════════════════════════════════

# LOGIN
argocd login <server> --username admin --password <pass> --insecure

# APP MANAGEMENT
argocd app list                            # List all apps
argocd app get <app>                       # Get app details
argocd app create <app> [flags]            # Create app
argocd app delete <app>                    # Delete app (and resources if finalizer set)
argocd app set <app> --sync-policy auto    # Modify app settings

# SYNC
argocd app sync <app>                      # Sync app
argocd app sync <app> --dry-run            # Preview sync
argocd app sync <app> --force              # Force sync (replace conflicts)
argocd app sync <app> --revision <sha>     # Sync to specific commit
argocd app sync <app> --resource <group:Kind:name>  # Sync single resource

# STATUS & TROUBLESHOOTING
argocd app diff <app>                      # Show diff (desired vs actual)
argocd app history <app>                   # Show deployment history
argocd app resources <app>                 # List managed resources
argocd app logs <app>                      # View app logs
argocd app wait <app> --health             # Wait for healthy status

# ROLLBACK
argocd app rollback <app> <history-id>     # Rollback to history entry
argocd app terminate-op <app>              # Stop stuck operation

# REPO MANAGEMENT
argocd repo add <url>                      # Register repository
argocd repo list                           # List repositories
argocd repo remove <url>                   # Remove repository

# PROJECT MANAGEMENT
argocd proj create <project>               # Create project
argocd proj list                           # List projects
argocd proj get <project>                  # Get project details

# CLUSTER MANAGEMENT
argocd cluster add <context>               # Register cluster
argocd cluster list                        # List clusters

# ACCOUNT MANAGEMENT
argocd account list                        # List accounts
argocd account generate-token --account <name>  # Generate API token
argocd account update-password            # Update current user password
```

---

> **Learning Path Recommendation:**
> 1. Start with Labs 1–2 to build confidence with basic GitOps workflows
> 2. Complete Lab 3 (Kustomize) once you're comfortable with deployments
> 3. Tackle Labs 4–5 (Hooks, RBAC) for production-readiness knowledge
> 4. Build the Final Project to tie everything together
> 5. Explore Section 16 (Argo Rollouts, ApplicationSets) for advanced enterprise patterns

---

*Guide maintained by: Platform Engineering Team | Last updated: 2024*
*ArgoCD Documentation: https://argo-cd.readthedocs.io*
*ArgoCD GitHub: https://github.com/argoproj/argo-cd*

---

## 19. Advanced ApplicationSet Patterns

ApplicationSet is the GitOps-native way to dynamically manage hundreds of applications without writing them one by one. This section covers every generator type used in production.

### 19.1 Matrix Generator (Combine Two Generators)

The Matrix generator creates the Cartesian product of two generators — perfect for managing multiple apps across multiple clusters.

```yaml
# Deploy every app in every cluster automatically
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps-all-clusters
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      # Generator 1: Clusters (from ArgoCD cluster secrets)
      - clusters:
          selector:
            matchLabels:
              env: production            # Only production clusters
      # Generator 2: Git directories (one per microservice)
      - git:
          repoURL: https://github.com/your-org/my-gitops-repo.git
          revision: HEAD
          directories:
          - path: "services/*"
  template:
    metadata:
      name: "{{path.basename}}-{{name}}"  # e.g., frontend-cluster-eu-west
    spec:
      project: production
      source:
        repoURL: https://github.com/your-org/my-gitops-repo.git
        targetRevision: HEAD
        path: "{{path}}"
      destination:
        server: "{{server}}"
        namespace: "{{path.basename}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### 19.2 Pull Request Generator (Preview Environments)

Create a temporary environment for every open Pull Request — and destroy it when the PR is merged or closed.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: preview-environments
  namespace: argocd
spec:
  generators:
  - pullRequest:
      github:
        owner: your-org
        repo: my-app
        tokenRef:
          secretName: github-token
          key: token
        labels:
        - preview                           # Only PRs with 'preview' label get an environment
      requeueAfterSeconds: 60               # Check for new PRs every 60 seconds

  template:
    metadata:
      name: "preview-pr-{{number}}"
      labels:
        app-type: preview
        pr-number: "{{number}}"
      annotations:
        # Auto-delete after PR is closed (handled by ArgoCD)
        argocd.argoproj.io/manifest-generate-paths: "."
    spec:
      project: dev-project
      source:
        repoURL: https://github.com/your-org/my-app.git
        targetRevision: "{{head_sha}}"      # Deploy exact PR commit
        path: helm/myapp
        helm:
          releaseName: "pr-{{number}}"
          values: |
            image:
              tag: "pr-{{number}}-{{head_short_sha}}"
            ingress:
              host: "pr-{{number}}.preview.company.com"
            replicaCount: 1
      destination:
        server: https://kubernetes.default.svc
        namespace: "preview-pr-{{number}}"  # Isolated namespace per PR
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### 19.3 SCM Provider Generator (All Repos in an Org)

```yaml
# Deploy apps from EVERY repo in your GitHub org that has a specific file
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: org-wide-apps
  namespace: argocd
spec:
  generators:
  - scmProvider:
      github:
        organization: your-org
        tokenRef:
          secretName: github-token
          key: token
        allBranches: false                  # Only default branches
      filters:
      - repositoryMatch: "^service-"        # Only repos starting with 'service-'
        pathsExist:
        - helm/Chart.yaml                   # Only repos with a Helm chart
  template:
    metadata:
      name: "{{repository}}"
    spec:
      project: platform
      source:
        repoURL: "{{url}}"
        targetRevision: "{{branch}}"
        path: helm
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{repository}}"
      syncPolicy:
        automated:
          prune: true
```

### 19.4 Cluster Generator with Cluster Secrets

Label your cluster secrets in ArgoCD to auto-deploy to new clusters when they join:

```bash
# When registering a cluster, label it
argocd cluster add prod-eu-west-1 \
  --label env=production \
  --label region=eu-west-1 \
  --label team=platform

# ApplicationSet automatically creates apps for this cluster
# because it selects clusters by label: env=production
```

### 19.5 ApplicationSet Template Patch (Override per App)

```yaml
spec:
  generators:
  - list:
      elements:
      - name: frontend
        namespace: frontend-prod
        replicas: "5"
        resources: "high"
      - name: backend
        namespace: backend-prod
        replicas: "3"
        resources: "medium"

  # Global template
  template:
    metadata:
      name: "{{name}}-prod"
    spec:
      source:
        path: "services/{{name}}"

  # Per-element patch (overrides template fields)
  templatePatch: |
    spec:
      source:
        helm:
          parameters:
          - name: replicaCount
            value: "{{replicas}}"
          - name: resources.preset
            value: "{{resources}}"
```

---

## 20. ArgoCD Notifications (Deep Dive)

Notifications let ArgoCD proactively alert your team on Slack, email, PagerDuty, Teams, and more when applications change state.

### 20.1 Install and Configure Notifications

```bash
# Verify notifications controller is running
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-notifications-controller

# Install notification catalog (pre-built templates)
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

### 20.2 Slack Integration

```yaml
# Step 1: Create Slack bot token secret
kubectl create secret generic argocd-notifications-secret \
  --from-literal=slack-token=xoxb-your-slack-bot-token \
  -n argocd

# Step 2: Configure argocd-notifications-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Define notification services
  service.slack: |
    token: $slack-token
    username: ArgoCD
    icon: ":argo:"

  # ─── Templates ────────────────────────────────────────────
  template.app-sync-succeeded: |
    slack:
      attachments: |
        [{
          "title": "✅ {{.app.metadata.name}} Sync Succeeded",
          "color": "#18BE52",
          "fields": [
            {"title": "Environment", "value": "{{.app.metadata.labels.environment}}", "short": true},
            {"title": "Revision",    "value": "{{.app.status.sync.revision | truncate 7 ''}}", "short": true},
            {"title": "Namespace",   "value": "{{.app.spec.destination.namespace}}", "short": true},
            {"title": "Duration",    "value": "{{.app.status.operationState.finishedAt}}", "short": true}
          ],
          "actions": [{
            "type": "button",
            "text": "Open in ArgoCD",
            "url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}"
          }]
        }]

  template.app-sync-failed: |
    slack:
      attachments: |
        [{
          "title": "🔴 {{.app.metadata.name}} Sync FAILED",
          "color": "#E53935",
          "fields": [
            {"title": "Environment", "value": "{{.app.metadata.labels.environment}}", "short": true},
            {"title": "Revision",    "value": "{{.app.status.sync.revision | truncate 7 ''}}", "short": true},
            {"title": "Error",       "value": "{{.app.status.operationState.message}}"}
          ]
        }]

  template.app-health-degraded: |
    slack:
      attachments: |
        [{
          "title": "⚠️ {{.app.metadata.name}} Health DEGRADED",
          "color": "#FF6D00",
          "fields": [
            {"title": "Health", "value": "{{.app.status.health.status}}", "short": true},
            {"title": "Message", "value": "{{.app.status.health.message}}"}
          ]
        }]

  template.app-deployed: |
    slack:
      blocks: |
        [{
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*🚀 New Deployment: {{.app.metadata.name}}*\n*Revision:* `{{.app.status.sync.revision | truncate 7 ''}}`\n*Author:* {{(call .repo.GetCommitMetadata .app.status.sync.revision).Author}}\n*Message:* {{(call .repo.GetCommitMetadata .app.status.sync.revision).Message}}"
          }
        }]

  # ─── Triggers ─────────────────────────────────────────────
  trigger.on-sync-succeeded: |
    - description: Notify when app sync succeeds
      send:
      - app-sync-succeeded
      when: app.status.operationState.phase in ['Succeeded']

  trigger.on-sync-failed: |
    - description: Notify when app sync fails
      send:
      - app-sync-failed
      when: app.status.operationState.phase in ['Error', 'Failed']

  trigger.on-health-degraded: |
    - description: Notify when app health becomes degraded
      send:
      - app-health-degraded
      when: app.status.health.status == 'Degraded'

  trigger.on-deployed: |
    - description: Notify on every new deployment
      send:
      - app-deployed
      when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'

  # ─── Default subscriptions ────────────────────────────────
  # Subscribe ALL apps to these triggers by default
  subscriptions: |
    - recipients:
      - slack:#argocd-alerts
      triggers:
      - on-sync-failed
      - on-health-degraded
    - recipients:
      - slack:#deployments
      triggers:
      - on-deployed
```

### 20.3 Per-Application Notification Subscription

Instead of global subscriptions, annotate individual apps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-prod
  namespace: argocd
  annotations:
    # Subscribe this app to specific triggers on specific channels
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: "#frontend-team"
    notifications.argoproj.io/subscribe.on-sync-failed.slack: "#platform-alerts,#frontend-team"
    notifications.argoproj.io/subscribe.on-health-degraded.slack: "#oncall"
    # Email notifications
    notifications.argoproj.io/subscribe.on-sync-failed.email: "oncall@company.com"
    # PagerDuty on production degraded
    notifications.argoproj.io/subscribe.on-health-degraded.pagerduty: "<pagerduty-integration-key>"
```

### 20.4 PagerDuty & Email Integration

```yaml
# In argocd-notifications-cm
data:
  # PagerDuty service
  service.pagerduty: |
    token: $pagerduty-token

  template.app-degraded-pagerduty: |
    pagerduty:
      severity: critical
      summary: "{{.app.metadata.name}} is Degraded in {{.app.metadata.labels.environment}}"
      source: "{{.app.spec.destination.server}}"
      component: "{{.app.metadata.name}}"
      group: "{{.app.metadata.labels.team}}"

  # Email service (SMTP)
  service.email: |
    host: smtp.company.com
    port: 587
    from: argocd@company.com
    username: argocd@company.com
    password: $smtp-password
    tls:
      insecureSkipVerify: false

  template.app-failed-email: |
    email:
      subject: "[ArgoCD] ❌ {{.app.metadata.name}} Sync Failed"
      body: |
        Application {{.app.metadata.name}} sync failed.

        Environment: {{.app.metadata.labels.environment}}
        Revision: {{.app.status.sync.revision}}
        Error: {{.app.status.operationState.message}}

        View in ArgoCD: {{.context.argocdUrl}}/applications/{{.app.metadata.name}}
```

---

## 21. High Availability (HA) Setup

In production, run ArgoCD in HA mode to ensure zero-downtime operations.

### 21.1 HA Architecture

```
                          Load Balancer
                               │
             ┌─────────────────┼─────────────────┐
             │                 │                 │
      argocd-server      argocd-server     argocd-server
        (replica 1)        (replica 2)       (replica 3)
             │                 │                 │
             └────────────┬────┘                 │
                          │                      │
                     Redis HA (Sentinel or Cluster)
                          │
             ┌────────────┴────────────┐
    argocd-repo-server          argocd-repo-server
       (replica 1)                 (replica 2)
             │
    argocd-application-controller-0   (StatefulSet — single active, uses leader election)
```

### 21.2 Deploy ArgoCD in HA Mode

```bash
# Apply the HA install manifest instead of the standard one
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# Verify HA components
kubectl get pods -n argocd
# argocd-server (3 replicas)
# argocd-repo-server (2 replicas)
# argocd-application-controller-0 (single, leader election via Redis)
# argocd-redis-ha-server-0/1/2 (3-node Redis Sentinel)
```

### 21.3 HA Configuration Tuning

```yaml
# argocd-cmd-params-cm — tune performance for large clusters
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Application controller — increase parallelism for large environments
  controller.status.processors: "50"        # Concurrent status processors (default: 20)
  controller.operation.processors: "25"     # Concurrent operation processors (default: 10)
  controller.repo.server.timeout.seconds: "120"  # Repo server timeout

  # Repo server — more workers for concurrent manifest generation
  reposerver.parallelism.limit: "10"

  # Server — tune request timeouts
  server.grpc.max.size.mb: "200"

  # Application state cache TTL
  controller.app.state.cache.expiration: "3h"

  # Reconciliation interval (how often to check Git)
  timeout.reconciliation: "180s"            # Default is 3 minutes — increase for large repos

  # Hard reconciliation (full re-fetch from Git, bypassing cache)
  timeout.hard.reconciliation: "3600s"      # Full refresh every hour
```

### 21.4 Redis HA with Sentinel

```yaml
# For production, use an external Redis Sentinel cluster
# argocd-cmd-params-cm
data:
  redis.server: "redis-sentinel-master.redis.svc:6379"
  redis.sentinel.addrs: "redis-sentinel-0:26379,redis-sentinel-1:26379,redis-sentinel-2:26379"
  redis.sentinel.master: "mymaster"
  redis.password: "$redis-password"
```

### 21.5 Pod Disruption Budgets

```yaml
# Ensure at least 2 ArgoCD servers are always available during node maintenance
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-server-pdb
  namespace: argocd
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-repo-server-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
```

---

## 22. Security Hardening

### 22.1 Network Policies

Restrict which pods can communicate with ArgoCD components:

```yaml
# Only allow ingress to argocd-server from ingress controller and specific namespaces
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from ingress controller (nginx)
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 8443
  # Allow from monitoring (Prometheus scraping)
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    ports:
    - protocol: TCP
      port: 8083
  egress:
  # Allow to repo-server
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-repo-server
    ports:
    - port: 8081
  # Allow to Redis
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-redis
    ports:
    - port: 6379
  # Allow DNS
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP

---
# Repo server: only accepts connections from argocd-server and app-controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-repo-server-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-server
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-application-controller
    ports:
    - port: 8081
  egress:
  # Allow HTTPS to Git repositories
  - ports:
    - port: 443
    - port: 22                    # SSH for Git
  - to:
    - namespaceSelector: {}
    ports:
    - port: 53
      protocol: UDP
```

### 22.2 TLS Certificates with cert-manager

```yaml
# Issue a valid TLS cert for the ArgoCD ingress
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - argocd.company.com

---
# ArgoCD Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"    # Pass TLS directly to ArgoCD
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - argocd.company.com
    secretName: argocd-tls-cert
  rules:
  - host: argocd.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

### 22.3 Run ArgoCD Components as Non-Root

```yaml
# Patch argocd-server Deployment to enforce non-root
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
      containers:
      - name: argocd-server
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

### 22.4 ArgoCD API Token Best Practices

```bash
# Create short-lived tokens for CI pipelines (expires in 24 hours)
argocd account generate-token \
  --account ci-robot \
  --expires-in 24h

# Rotate tokens regularly via a CronJob
cat > rotate-argocd-token.sh <<'EOF'
#!/bin/bash
# Run daily to rotate CI tokens
NEW_TOKEN=$(argocd account generate-token --account ci-robot --expires-in 24h)
kubectl create secret generic argocd-ci-token \
  --from-literal=token=$NEW_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -
echo "Token rotated successfully"
EOF
```

### 22.5 Restrict ArgoCD from Managing Sensitive Namespaces

```yaml
# Use AppProject to DENY access to kube-system and kube-public
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: restricted-project
  namespace: argocd
spec:
  destinations:
  # Allow all namespaces except system namespaces
  - namespace: "app-*"
    server: https://kubernetes.default.svc
  - namespace: "team-*"
    server: https://kubernetes.default.svc
  # Deny kube-system and kube-public by omission
  # Never include these in destinations

  # Only allow safe cluster-scoped resources
  clusterResourceWhitelist:
  - group: ""
    kind: Namespace

  # Block all CRDs that could escalate privileges
  namespaceResourceBlacklist:
  - group: "rbac.authorization.k8s.io"
    kind: ClusterRoleBinding
  - group: "rbac.authorization.k8s.io"
    kind: ClusterRole
```

### 22.6 Audit & Compliance

```bash
# Enable structured audit logging on the ArgoCD API server
# argocd-cmd-params-cm
data:
  server.log.format: json                  # JSON logs for log aggregation (Loki, Elasticsearch)
  server.log.level: info

# Query audit events (example with jq)
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-server \
  --since=24h \
  | jq 'select(.msg | contains("sync") or contains("delete") or contains("create"))
        | {time: .time, user: .user, action: .msg, app: .app}'
```

---

## 23. Performance Tuning & Scaling

### 23.1 Sharding the Application Controller

When managing 1000+ applications, shard the application controller to distribute the workload.

```yaml
# Scale app controller to multiple replicas (sharded)
# Each shard handles a subset of clusters
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: argocd-application-controller
  namespace: argocd
spec:
  replicas: 3                              # 3 shards
  template:
    spec:
      containers:
      - name: argocd-application-controller
        env:
        - name: ARGOCD_CONTROLLER_REPLICAS
          value: "3"                        # Must match spec.replicas
```

```yaml
# argocd-cmd-params-cm — enable sharding
data:
  controller.sharding.algorithm: "round-robin"    # or legacy
  # Each application controller shard handles ~333 clusters (1000 / 3)
```

### 23.2 Resource Requests & Limits Tuning

```yaml
# Tune based on number of applications and clusters managed
# Small (< 100 apps):    Default resources
# Medium (100-500 apps): Below values
# Large (500+ apps):     Double the below values

# argocd-application-controller StatefulSet
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "4Gi"

# argocd-repo-server Deployment
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1"
    memory: "2Gi"

# argocd-server Deployment
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### 23.3 Optimize Repository Caching

```yaml
# argocd-cmd-params-cm
data:
  # How long to cache generated manifests (reduce repo-server load)
  reposerver.cache.expiration: "24h"

  # Increase parallel manifest generation for large repos
  reposerver.parallelism.limit: "20"

  # Compress repository cache (useful for large repos)
  reposerver.enable.git.submodule: "false"  # Disable if not using submodules
```

### 23.4 Horizontal Pod Autoscaler for ArgoCD Server

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: argocd-server-hpa
  namespace: argocd
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: argocd-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 24. GitOps with Service Mesh (Istio)

### 24.1 Deploying Istio via ArgoCD

```yaml
# Deploy Istio using its own Helm charts via ArgoCD
# Step 1: Istio base (CRDs)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-base
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: platform
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: base
    targetRevision: 1.19.3
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true

---
# Step 2: istiod (control plane)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istiod
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: platform
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: istiod
    targetRevision: 1.19.3
    helm:
      values: |
        pilot:
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
```

### 24.2 Ignore Istio Injected Annotations

Istio sidecar injection adds annotations to pods that ArgoCD sees as drift:

```yaml
# In your Application spec — ignore Istio-added fields
spec:
  ignoreDifferences:
  # Ignore sidecar injection status
  - group: apps
    kind: Deployment
    jqPathExpressions:
    - .spec.template.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]
    - .spec.template.metadata.annotations["sidecar.istio.io/status"]
  # Ignore Istio injected proxy container
  - group: apps
    kind: Deployment
    jqPathExpressions:
    - .spec.template.spec.containers[] | select(.name == "istio-proxy")
    - .spec.template.spec.initContainers[] | select(.name == "istio-init")
```

### 24.3 Traffic Management with Argo Rollouts + Istio

```yaml
# Canary with Istio traffic splitting (no need for separate canary service)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: frontend
spec:
  strategy:
    canary:
      canaryService: frontend-canary-svc
      stableService: frontend-stable-svc
      trafficRouting:
        istio:
          virtualService:
            name: frontend-vsvc
            routes:
            - primary
      steps:
      - setWeight: 5             # 5% to canary
      - pause: {duration: 10m}
      - setWeight: 20
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100
```

---

## 25. Policy Enforcement (OPA / Gatekeeper)

### 25.1 Deploy Gatekeeper via ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gatekeeper
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://open-policy-agent.github.io/gatekeeper/charts
    chart: gatekeeper
    targetRevision: 3.14.0
    helm:
      values: |
        replicas: 2
        auditInterval: 60
  destination:
    server: https://kubernetes.default.svc
    namespace: gatekeeper-system
  syncPolicy:
    automated:
      prune: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

### 25.2 Enforce Resource Limits on All Pods

```yaml
# ConstraintTemplate: Define the policy logic
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: RequireResourceLimits
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package requireresourcelimits

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not container.resources.limits.cpu
        msg := sprintf("Container '%v' must have CPU limits set", [container.name])
      }

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not container.resources.limits.memory
        msg := sprintf("Container '%v' must have memory limits set", [container.name])
      }

---
# Constraint: Apply the policy to all namespaces except system
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequireResourceLimits
metadata:
  name: must-have-resource-limits
spec:
  enforcementAction: deny                  # deny | warn | dryrun
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment", "StatefulSet", "DaemonSet"]
    excludedNamespaces:
    - kube-system
    - kube-public
    - argocd
    - monitoring
```

### 25.3 Require Specific Labels on All Applications

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: requirelabels
spec:
  crd:
    spec:
      names:
        kind: RequireLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package requirelabels

      violation[{"msg": msg}] {
        required := input.parameters.labels[_]
        not input.review.object.metadata.labels[required]
        msg := sprintf("Missing required label: '%v'", [required])
      }

---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequireLabels
metadata:
  name: all-deployments-must-have-labels
spec:
  enforcementAction: warn
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
  parameters:
    labels:
    - "app"
    - "team"
    - "environment"
    - "managed-by"
```

---

## 26. Custom ArgoCD Plugins (Config Management Plugins)

### 26.1 When to Use a Custom Plugin

Use a custom Config Management Plugin (CMP) when your manifests need a tool ArgoCD doesn't support natively. Examples:

- **Helm with external secret injection** (Helm + Vault)
- **Custom templating tools** (cue, dhall, jsonnet)
- **Environment-specific pre-processing scripts**

### 26.2 Define a Sidecar Plugin (Modern Method — v2.5+)

```yaml
# Add the plugin as a sidecar in argocd-repo-server
# Patch the repo-server Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
spec:
  template:
    spec:
      volumes:
      - name: custom-tools
        emptyDir: {}
      initContainers:
      # Download the custom tool at startup
      - name: download-my-tool
        image: alpine:latest
        command:
        - sh
        - -c
        - |
          wget -O /custom-tools/my-tool https://example.com/my-tool
          chmod +x /custom-tools/my-tool
        volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools
      containers:
      # Existing repo-server container
      - name: argocd-repo-server
        volumeMounts:
        - name: custom-tools
          mountPath: /usr/local/bin/my-tool
          subPath: my-tool
      # Plugin sidecar container
      - name: my-plugin
        image: alpine:latest
        command: [/var/run/argocd/argocd-cmp-server]
        env:
        - name: MY_ENV_VAR
          value: "some-value"
        volumeMounts:
        - name: custom-tools
          mountPath: /usr/local/bin
        - mountPath: /var/run/argocd
          name: var-files
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
        - mountPath: /tmp
          name: tmp

      # Required shared volumes
      volumes:
      - emptyDir: {}
        name: var-files
      - emptyDir: {}
        name: plugins
      - emptyDir: {}
        name: tmp
```

```yaml
# Plugin definition ConfigMap (mounted into sidecar)
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-plugin-config
  namespace: argocd
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: my-plugin
    spec:
      version: v1.0
      init:
        command: [sh, -c, "echo 'Initializing plugin...'"]
      generate:
        command: [sh, -c]
        args:
        - |
          # Custom manifest generation logic
          my-tool generate \
            --env $ARGOCD_ENV_ENVIRONMENT \
            --output-dir /tmp/output
          cat /tmp/output/*.yaml
      discover:
        # Auto-discover repos using this plugin
        find:
          glob: "**/my-tool.yaml"
```

### 26.3 Use the Plugin in an Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: custom-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/my-gitops-repo.git
    targetRevision: HEAD
    path: apps/custom-app
    plugin:
      name: my-plugin                      # Must match plugin.yaml metadata.name
      env:
      - name: ENVIRONMENT
        value: production
      - name: CUSTOM_FLAG
        value: "true"
  destination:
    server: https://kubernetes.default.svc
    namespace: custom-app
```

---

## 27. Webhook Configuration

Webhooks make ArgoCD respond to Git events in seconds instead of waiting for the polling interval (default: 3 minutes).

### 27.1 GitHub Webhook Setup

```bash
# Step 1: Get or create the webhook secret
WEBHOOK_SECRET=$(kubectl get secret argocd-secret -n argocd \
  -o jsonpath='{.data.webhook\.github\.secret}' | base64 -d)

# If not set, create one
NEW_SECRET=$(openssl rand -hex 32)
kubectl patch secret argocd-secret -n argocd \
  -p "{\"data\": {\"webhook.github.secret\": \"$(echo -n $NEW_SECRET | base64)\"}}"
echo "Webhook secret: $NEW_SECRET"  # Add this to GitHub
```

```
# Step 2: Add webhook in GitHub
Repository Settings → Webhooks → Add webhook
  Payload URL:   https://argocd.company.com/api/webhook
  Content type:  application/json
  Secret:        <secret from above>
  Events:        Push events ✓, Pull request events ✓ (for PR generator)
  Active:        ✓
```

### 27.2 GitLab Webhook

```yaml
# argocd-secret — add GitLab webhook secret
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  webhook.gitlab.secret: "your-gitlab-webhook-secret"
```

```
# GitLab: Settings → Webhooks
  URL:    https://argocd.company.com/api/webhook
  Token:  <secret from above>
  Trigger: Push events ✓, Tag push events ✓
```

### 27.3 Verify Webhook Delivery

```bash
# Watch ArgoCD server logs for incoming webhooks
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f \
  | grep -i webhook

# Successful webhook shows:
# {"level":"info","msg":"Received push event","provider":"github","repo":"your-org/my-gitops-repo"}
# {"level":"info","msg":"Refreshing app in response to webhook","application":"frontend-dev"}
```

---

## 28. Production Runbooks

### 28.1 Runbook: Recovering a Broken Application

```bash
#!/bin/bash
# runbook-recover-app.sh
# Usage: ./runbook-recover-app.sh <app-name>

APP=$1
echo "=== RECOVERING APPLICATION: $APP ==="

echo "--- Step 1: Check current state ---"
argocd app get $APP

echo "--- Step 2: Check recent events ---"
kubectl get events -n $(argocd app get $APP -o json | jq -r '.spec.destination.namespace') \
  --sort-by='.lastTimestamp' | tail -20

echo "--- Step 3: Terminate stuck operations ---"
argocd app terminate-op $APP 2>/dev/null || echo "No operation to terminate"

echo "--- Step 4: Hard refresh (bypass cache) ---"
argocd app get $APP --hard-refresh

echo "--- Step 5: Attempt sync ---"
argocd app sync $APP --retry-limit 3

echo "--- Step 6: Wait for health ---"
argocd app wait $APP --health --timeout 180

echo "--- Step 7: Final state ---"
argocd app get $APP
```

### 28.2 Runbook: ArgoCD Full Disaster Recovery

```bash
#!/bin/bash
# runbook-argocd-dr.sh
# Run this on a new cluster after a catastrophic failure

ARGOCD_VERSION="v2.9.0"
GITOPS_REPO="https://github.com/your-org/my-gitops-repo.git"
GITOPS_PAT="<personal-access-token>"

echo "=== ARGOCD DISASTER RECOVERY ==="

# Step 1: Install ArgoCD
echo "--- Installing ArgoCD $ARGOCD_VERSION ---"
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/ha/install.yaml

# Step 2: Wait for ArgoCD to be ready
echo "--- Waiting for ArgoCD pods ---"
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s

# Step 3: Get initial password and login
INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 3
argocd login localhost:8080 --username admin --password $INITIAL_PASS --insecure

# Step 4: Register the GitOps repository
echo "--- Registering Git repository ---"
argocd repo add $GITOPS_REPO \
  --username git \
  --password $GITOPS_PAT

# Step 5: Apply backup of ArgoCD resources (Applications + Projects)
echo "--- Restoring ArgoCD configuration from backup ---"
kubectl apply -f argocd-backup-latest.yaml

# Step 6: Sync all applications from Git
echo "--- Syncing all applications from Git ---"
argocd app sync \
  $(argocd app list -o name | tr '\n' ' ') \
  --async

echo "=== DR COMPLETE — Monitor sync progress in ArgoCD UI ==="
```

### 28.3 Runbook: Production Deployment Checklist

```
PRE-DEPLOYMENT CHECKLIST
═════════════════════════

[ ] 1. Git tag created for production release (e.g., v1.5.0)
[ ] 2. Image tagged and pushed to production registry
[ ] 3. PR approved with at least 2 reviewers
[ ] 4. prod kustomization.yaml updated with new image tag
[ ] 5. ArgoCD diff reviewed: argocd app diff <app-name>
[ ] 6. Staging (QA) deployment verified healthy
[ ] 7. Database migrations tested in staging
[ ] 8. Rollback plan documented (previous tag: v1.4.9)
[ ] 9. On-call engineer alerted
[ ] 10. Sync window is open (per project syncWindows config)

DEPLOYMENT STEPS
═════════════════

[ ] 1. argocd app sync <prod-app> --dry-run       # Final preview
[ ] 2. argocd app sync <prod-app>                 # Trigger sync
[ ] 3. argocd app wait <prod-app> --health --timeout 600
[ ] 4. Run smoke tests: ./scripts/smoke-test-prod.sh
[ ] 5. Monitor error rates for 10 minutes
[ ] 6. Check Grafana dashboard for anomalies

POST-DEPLOYMENT CHECKLIST
══════════════════════════

[ ] 1. argocd app get <prod-app>   → Health: Healthy, Sync: Synced
[ ] 2. kubectl get pods -n prod-namespace  → All pods Running
[ ] 3. Application metrics normal (response time, error rate)
[ ] 4. Update deployment log with: date, who deployed, version
[ ] 5. Notify stakeholders

ROLLBACK TRIGGERS (rollback immediately if):
═════════════════════════════════════════════
→ Error rate increases > 1% above baseline
→ P99 latency doubles
→ Any pod in CrashLoopBackOff for > 2 minutes
→ Database connection errors spike
```

### 28.4 Daily Operations Commands

```bash
# Morning health check script
#!/bin/bash
echo "=== ArgoCD Daily Health Check $(date) ==="

echo "--- Applications Out of Sync ---"
argocd app list | grep -v "Synced" | grep -v "NAME"

echo "--- Applications Degraded ---"
argocd app list | grep "Degraded" || echo "✅ All apps healthy"

echo "--- Recent Sync Failures (last 1h) ---"
kubectl logs -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller \
  --since=1h | grep -i "error\|fail" | tail -20

echo "--- ArgoCD Component Health ---"
kubectl get pods -n argocd

echo "--- Repository Connectivity ---"
argocd repo list

echo "=== Health Check Complete ==="
```

---

## 29. ArgoCD Upgrade & Maintenance

### 29.1 Safe Upgrade Procedure

```bash
# Step 1: Read the release notes first!
# https://github.com/argoproj/argo-cd/releases

# Step 2: Check current version
argocd version

# Step 3: Backup current state
kubectl get applications,appprojects -n argocd -o yaml \
  > argocd-backup-before-upgrade-$(date +%Y%m%d-%H%M%S).yaml

# Step 4: Apply new version (minor version — safe for rolling upgrade)
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/ha/install.yaml

# Step 5: Monitor the rolling update
kubectl rollout status deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-repo-server -n argocd
kubectl rollout status statefulset/argocd-application-controller -n argocd

# Step 6: Verify new version
argocd version
kubectl get pods -n argocd

# Step 7: Test basic operations
argocd app list
argocd app sync <non-critical-test-app> --dry-run
```

### 29.2 Version Compatibility Matrix

```
ArgoCD Version  | Kubernetes Versions Supported
────────────────────────────────────────────────
v2.10.x         | 1.26, 1.27, 1.28, 1.29
v2.9.x          | 1.25, 1.26, 1.27, 1.28
v2.8.x          | 1.24, 1.25, 1.26, 1.27

NOTE: ArgoCD N-2 version skew is supported for upgrades.
      Always upgrade one minor version at a time.
      e.g., v2.7 → v2.8 → v2.9 (NOT v2.7 → v2.9 directly)
```

### 29.3 Maintenance Tasks

```bash
# Clean up stale completed sync operations
kubectl delete pods -n argocd \
  --field-selector=status.phase=Succeeded

# Compact Redis cache (if running standalone Redis)
kubectl exec -n argocd \
  $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-redis -o name) \
  -- redis-cli BGREWRITEAOF

# Garbage collect old ArgoCD application controller metrics
kubectl delete pods -n argocd \
  -l app.kubernetes.io/name=argocd-application-controller

# Clean up terminated PreSync/PostSync hook Jobs
kubectl delete jobs -n <app-namespace> \
  --field-selector=status.conditions[0].type=Complete
```

---

## 30. Glossary

| Term | Definition |
|------|------------|
| **Application (App)** | An ArgoCD CRD (`argoproj.io/v1alpha1/Application`) that maps a Git source to a Kubernetes destination and tracks sync/health state. |
| **AppProject** | An ArgoCD CRD that defines boundaries for a group of Applications — allowed repos, destinations, cluster resources, and RBAC roles. |
| **ApplicationSet** | An ArgoCD CRD that dynamically generates multiple `Application` resources using generators (Git, List, Cluster, Matrix, PR, etc.). |
| **Auto-Sync** | An ArgoCD policy (`syncPolicy.automated`) that automatically applies Git changes to the cluster without manual intervention. |
| **Config Management Plugin (CMP)** | A custom manifest generator plugin that runs as a sidecar in argocd-repo-server, for tools not natively supported (e.g., custom scripts). |
| **CRD** | Custom Resource Definition — Kubernetes API extension used by ArgoCD to define its own resources (Application, AppProject, etc.). |
| **Declarative** | Describing the desired end state (YAML) rather than the steps to achieve it. GitOps is built on declarative configuration. |
| **Drift** | When the actual cluster state diverges from the desired state stored in Git — caused by manual `kubectl` commands or external controllers. |
| **Generator** | A component inside ApplicationSet that produces Application parameters from sources like Git directories, cluster lists, or PR events. |
| **GitOps** | An operational model where Git is the single source of truth for both application and infrastructure configuration, managed by automated operators. |
| **Hard Refresh** | An ArgoCD operation that forces a fresh clone from Git and regenerates manifests, bypassing all caches. |
| **Health Status** | The condition of Kubernetes resources managed by an Application: Healthy, Progressing, Degraded, Missing, Suspended, Unknown. |
| **Hook** | A Kubernetes resource (typically a Job) annotated to run at a specific phase of the ArgoCD sync lifecycle: PreSync, Sync, PostSync, SyncFail. |
| **Image Updater** | An ArgoCD Labs tool that automatically detects new container image versions and updates the GitOps repository's image tags. |
| **Kustomize** | A Kubernetes-native configuration management tool that uses a base + overlays pattern to customize manifests without templating. |
| **OutOfSync** | The sync status when the cluster state does not match the desired state in Git. |
| **Prune** | An ArgoCD sync option that deletes Kubernetes resources that exist in the cluster but have been removed from Git. |
| **Reconciliation** | The continuous process by which the Application Controller compares desired (Git) vs. actual (cluster) state and corrects any differences. |
| **Repo Server** | The ArgoCD component that clones repositories and renders Kubernetes manifests from Helm, Kustomize, or raw YAML. |
| **Self-Heal** | An ArgoCD policy (`selfHeal: true`) that automatically reverts any manual changes made directly to the cluster to match the Git state. |
| **Sealed Secrets** | A Kubernetes controller (by Bitnami) that encrypts Kubernetes Secrets with a cluster-specific key, making them safe to store in Git. |
| **Sync** | The operation that brings the actual cluster state in line with the desired state defined in Git. |
| **Sync Wave** | A numeric annotation (`argocd.argoproj.io/sync-wave`) that controls the order in which resources within an Application are applied. |
| **Sync Window** | A time-based policy on an AppProject that controls WHEN syncs are allowed or denied (e.g., deny production syncs during business hours). |
| **Tracking Strategy** | How ArgoCD monitors the current Git revision: `HEAD`, a branch name, a tag, or a specific commit SHA. |

---

## 31. Interview Preparation: Key Concepts & Answers

### Q1: What is the difference between ArgoCD sync status and health status?

**Sync Status** answers: *Does Git match the cluster?*
- `Synced` → cluster state matches desired state in Git
- `OutOfSync` → there is a difference (drift) between Git and cluster

**Health Status** answers: *Is the application working correctly?*
- `Healthy` → all resources are available and ready
- `Degraded` → one or more resources have failed
- `Progressing` → resources are still starting up

You can have `Synced` + `Degraded` (cluster matches Git, but Git describes a broken state) or `OutOfSync` + `Healthy` (cluster is working but someone made a manual change that differs from Git).

---

### Q2: What happens when you enable selfHeal and someone runs kubectl edit directly on the cluster?

ArgoCD's application controller continuously reconciles (compares) the cluster state against Git. If `selfHeal: true` is enabled, within the reconciliation period (default 3 minutes, or sooner with webhooks), ArgoCD detects the drift and **automatically reverts** the manual change to match Git. The manual edit is essentially discarded. This enforces Git as the only valid way to make changes.

---

### Q3: How would you safely deploy to production with ArgoCD?

```
1. No auto-sync in production (syncPolicy.automated: null)
2. Pin targetRevision to a Git tag (not HEAD/branch)
3. Use AppProject with restrictive syncWindows
4. Require manual argocd app sync with --dry-run first
5. Use sync waves for dependent resources
6. Use pre-sync hooks for DB migrations
7. Use Argo Rollouts for canary/blue-green (not plain Deployments)
8. Configure post-sync smoke test hooks
9. Monitor with Prometheus + Grafana + PagerDuty alerts
10. Document rollback procedure with specific history IDs
```

---

### Q4: What is the App of Apps pattern and why is it used?

The App of Apps pattern uses a single root ArgoCD Application that points to a directory containing other ArgoCD `Application` manifests. When the root app syncs, it creates all the child applications, which in turn sync their own workloads.

**Why it is used:**
- Bootstrap an entire cluster from one `kubectl apply`
- Git is the source of truth for ArgoCD's own configuration
- Adding a new application = adding a YAML file to Git (no manual UI/CLI steps)
- Enables self-management of ArgoCD itself (ArgoCD manages itself)

---

### Q5: How do you handle secrets in a GitOps workflow?

Three production-grade approaches:

| Approach | Tool | How it works | Best for |
|----------|------|--------------|----------|
| Encrypt in Git | Sealed Secrets | Public-key encryption; only the cluster can decrypt | Simple setups, no external dependencies |
| Reference external | External Secrets Operator | Pulls from AWS/GCP/Azure Secret Manager at runtime | Cloud-native teams with existing secret managers |
| Template injection | ArgoCD Vault Plugin | Replaces placeholders at sync time from Vault | HashiCorp Vault users, complex secret workflows |

**Common mistake to avoid:** Using base64-encoded secrets directly in Git (base64 is encoding, not encryption — it is trivially reversible).

---

### Q6: What is the difference between Helm and Kustomize, and when do you choose each?

| | Helm | Kustomize |
|-|------|-----------|
| **Approach** | Templating with `{{ .Values.x }}` | Patching with strategic merge or JSON patches |
| **Learning curve** | Higher (Go templates, chart structure) | Lower (plain YAML + overlays) |
| **Packaging** | Can package and distribute charts (Artifact Hub) | Not designed for distribution |
| **Environment diff** | `values-env.yaml` overrides | Overlays (base + patch files) |
| **Hooks** | Helm hooks (`helm.sh/hook` annotations) | ArgoCD hooks (works separately) |
| **Choose when** | Need a reusable, parameterized package; installing community charts | Simple environment differentiation for your own apps; prefer plain YAML |

---

### Q7: What would you do if ArgoCD is stuck in OutOfSync but you can't see any differences?

```bash
# 1. Inspect the raw diff
argocd app diff <app> --refresh

# 2. Common hidden causes:
#    - Cluster controllers add annotations/labels (e.g., last-applied-configuration)
#    - HPA changed replica count from Git value
#    - Admission webhooks mutated the resource after apply
#    - defaultMode on volumes is normalized differently

# 3. Add ignoreDifferences for known controller-managed fields
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas              # HPA-managed
    managedFieldsManagers:
    - kube-controller-manager     # Ignore fields set by controllers

# 4. Use ServerSideApply to reduce annotation-based drift
syncOptions:
- ServerSideApply=true
```

---

### Q8: Explain how ArgoCD ApplicationSets improve large-scale GitOps management.

Without ApplicationSet, managing 50 applications across 5 clusters = 250 Application YAML files to write and maintain by hand. ApplicationSet removes this toil by generating Applications dynamically from a single template.

Real-world impact:
- **New cluster joins** → label the cluster secret → ApplicationSet automatically creates all apps for it
- **New service added** → add a directory to Git → Git Directory generator creates the Application automatically
- **New PR opened** → PR Generator spins up a preview environment; merging destroys it automatically
- **Multi-region rollout** → Matrix generator creates every service × every region combination with a single ApplicationSet

---

*Guide maintained by: Platform Engineering Team*
*ArgoCD Documentation: https://argo-cd.readthedocs.io*
*ArgoCD GitHub: https://github.com/argoproj/argo-cd*
*Argo Rollouts: https://argoproj.github.io/argo-rollouts*
*External Secrets Operator: https://external-secrets.io*
*Sealed Secrets: https://github.com/bitnami-labs/sealed-secrets*
