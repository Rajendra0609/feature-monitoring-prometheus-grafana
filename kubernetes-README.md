# ☸️ Kubernetes — Comprehensive Real-World Guide

> A practical, hands-on reference for deploying, managing, and operating Kubernetes in real-time production environments.

---

## 📋 Table of Contents

1. [Introduction to Kubernetes](#1-introduction-to-kubernetes)
2. [Setting Up a Kubernetes Environment](#2-setting-up-a-kubernetes-environment)
3. [Core Concepts](#3-core-concepts)
   - [Pods](#31-pods)
   - [Namespaces](#32-namespaces)
   - [Services](#33-services)
   - [Deployments](#34-deployments)
   - [ReplicaSets](#35-replicasets)
   - [StatefulSets](#36-statefulsets)
   - [DaemonSets](#37-daemonsets)
   - [ConfigMaps & Secrets](#38-configmaps--secrets)
   - [Persistent Volumes & Claims](#39-persistent-volumes--claims)
   - [Ingress](#310-ingress)
   - [RBAC](#311-rbac-role-based-access-control)
4. [Real-Time Use Cases & Best Practices](#4-real-time-use-cases--best-practices)
5. [Scaling & Auto-Scaling](#5-scaling--auto-scaling)
6. [Networking](#6-networking)
7. [Observability — Logging, Metrics & Tracing](#7-observability--logging-metrics--tracing)
8. [Security Hardening](#8-security-hardening)
9. [CI/CD Integration](#9-cicd-integration)
10. [Troubleshooting & Common Issues](#10-troubleshooting--common-issues)
11. [Helm — Kubernetes Package Manager](#11-helm--kubernetes-package-manager)
12. [Additional Resources & References](#12-additional-resources--references)

---

## 1. Introduction to Kubernetes

### What is Kubernetes?

Kubernetes (K8s) is an open-source container orchestration platform originally developed by Google and now maintained by the Cloud Native Computing Foundation (CNCF). It automates the deployment, scaling, and management of containerized applications.

### Why Kubernetes?

| Without Kubernetes | With Kubernetes |
|--------------------|-----------------|
| Manual container restarts | Self-healing via health checks |
| Static capacity planning | Auto-scaling based on load |
| Manual load balancing | Built-in service discovery & LB |
| Complex rollout management | Rolling updates & rollbacks |
| Siloed configurations | Declarative config via YAML |

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     CONTROL PLANE                        │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────┐ │
│  │  API Server  │  │  etcd      │  │  Scheduler      │ │
│  │  (kube-api)  │  │  (store)   │  │  (kube-sched)   │ │
│  └──────────────┘  └────────────┘  └─────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │          Controller Manager (kube-cm)              │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
              │               │               │
┌─────────────▼─┐  ┌──────────▼──┐  ┌────────▼───────┐
│   WORKER NODE  │  │ WORKER NODE │  │  WORKER NODE   │
│  ┌───────────┐ │  │ ┌─────────┐ │  │ ┌───────────┐  │
│  │  kubelet  │ │  │ │ kubelet │ │  │ │  kubelet  │  │
│  │ kube-proxy│ │  │ │kube-prxy│ │  │ │ kube-prxy │  │
│  │  Pods     │ │  │ │  Pods   │ │  │ │   Pods    │  │
│  └───────────┘ │  │ └─────────┘ │  │ └───────────┘  │
└────────────────┘  └─────────────┘  └────────────────┘
```

**Control Plane Components:**

- **API Server** — Single entry point for all cluster communication; validates and processes REST requests.
- **etcd** — Distributed key-value store holding the entire cluster state.
- **Scheduler** — Assigns Pods to Nodes based on resource availability and constraints.
- **Controller Manager** — Runs controllers (Node, ReplicaSet, Endpoint, etc.) to maintain desired state.

**Worker Node Components:**

- **kubelet** — Agent on every node; ensures containers are running and healthy.
- **kube-proxy** — Manages network rules and traffic routing for Services.
- **Container Runtime** — Executes containers (containerd, CRI-O, or Docker).

---

## 2. Setting Up a Kubernetes Environment

### Local Development

#### Option A: minikube (Recommended for Beginners)

```bash
# Install minikube (macOS)
brew install minikube

# Start a local cluster
minikube start --cpus=4 --memory=8192 --driver=docker

# Verify the cluster
kubectl cluster-info
kubectl get nodes

# Enable useful addons
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# Open the Kubernetes dashboard
minikube dashboard
```

#### Option B: kind (Kubernetes in Docker)

```bash
# Install kind
brew install kind  # macOS
# or
go install sigs.k8s.io/kind@latest

# Create a multi-node cluster
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

kind create cluster --name dev-cluster --config kind-config.yaml
kubectl cluster-info --context kind-dev-cluster
```

#### Option C: k3s (Lightweight Production-Like)

```bash
# Single-command install
curl -sfL https://get.k3s.io | sh -

# Check status
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

### Cloud-Managed Kubernetes

#### Amazon EKS

```bash
# Install eksctl
brew install eksctl

# Create cluster (takes ~15 min)
eksctl create cluster \
  --name production-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name production-cluster
```

#### Google GKE

```bash
# Create an Autopilot cluster (Google-managed nodes)
gcloud container clusters create-auto my-cluster \
  --region us-central1

# Get credentials
gcloud container clusters get-credentials my-cluster --region us-central1
```

#### Azure AKS

```bash
# Create resource group and cluster
az group create --name myResourceGroup --location eastus

az aks create \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys

az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Essential kubectl Configuration

```bash
# View and switch contexts
kubectl config get-contexts
kubectl config use-context production-cluster

# Set a default namespace
kubectl config set-context --current --namespace=my-app

# Create a useful alias
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
```

---

## 3. Core Concepts

### 3.1 Pods

A **Pod** is the smallest deployable unit in Kubernetes — it wraps one or more containers that share network and storage.

#### Basic Pod Manifest

```yaml
# pod-basic.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: default
  labels:
    app: nginx
    tier: frontend
spec:
  containers:
    - name: nginx
      image: nginx:1.25-alpine
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 15
        periodSeconds: 20
  restartPolicy: Always
```

```bash
# Apply and inspect
kubectl apply -f pod-basic.yaml
kubectl get pods -o wide
kubectl describe pod nginx-pod
kubectl logs nginx-pod
kubectl exec -it nginx-pod -- /bin/sh
```

#### Multi-Container Pod (Sidecar Pattern)

```yaml
# pod-sidecar.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logger
spec:
  containers:
    - name: main-app
      image: my-app:latest
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app
    - name: log-shipper
      image: fluent/fluent-bit:latest
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app
          readOnly: true
  volumes:
    - name: shared-logs
      emptyDir: {}
```

### 3.2 Namespaces

Namespaces provide logical isolation within a cluster — useful for environments (dev/staging/prod) and teams.

```bash
# Create and manage namespaces
kubectl create namespace staging
kubectl create namespace production

# List all resources across namespaces
kubectl get pods --all-namespaces
kubectl get pods -A
```

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: platform
```

#### Resource Quotas per Namespace

```yaml
# resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
    persistentvolumeclaims: "5"
```

### 3.3 Services

A **Service** exposes a set of Pods as a stable network endpoint, handling load balancing and service discovery.

#### ClusterIP (Internal Only)

```yaml
# service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

#### NodePort (External via Node IP)

```yaml
# service-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 3000
      nodePort: 30080   # 30000–32767 range
```

#### LoadBalancer (Cloud LB Integration)

```yaml
# service-lb.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 443
      targetPort: 8443
  loadBalancerSourceRanges:
    - 203.0.113.0/24
```

#### Headless Service (Direct Pod DNS)

```yaml
# service-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: cassandra
spec:
  clusterIP: None  # Makes it headless
  selector:
    app: cassandra
  ports:
    - port: 9042
```

### 3.4 Deployments

A **Deployment** manages a ReplicaSet and provides declarative updates, rollouts, and rollbacks.

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  namespace: production
  labels:
    app: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: api
        version: "2.1.0"
    spec:
      containers:
        - name: api
          image: myrepo/api:2.1.0
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
            - name: ENVIRONMENT
              value: "production"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
      terminationGracePeriodSeconds: 60
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: api
                topologyKey: kubernetes.io/hostname
```

```bash
# Deployment lifecycle
kubectl apply -f deployment.yaml
kubectl rollout status deployment/api-deployment
kubectl rollout history deployment/api-deployment

# Update image
kubectl set image deployment/api-deployment api=myrepo/api:2.2.0

# Rollback to previous version
kubectl rollout undo deployment/api-deployment

# Rollback to specific revision
kubectl rollout undo deployment/api-deployment --to-revision=2

# Pause and resume rollout
kubectl rollout pause deployment/api-deployment
kubectl rollout resume deployment/api-deployment
```

### 3.5 ReplicaSets

ReplicaSets ensure a specified number of Pod replicas are running. Typically managed by Deployments.

```yaml
# replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend-rs
spec:
  replicas: 5
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
```

```bash
kubectl get replicasets
kubectl scale replicaset frontend-rs --replicas=10
```

### 3.6 StatefulSets

**StatefulSets** manage stateful applications (databases, queues) with stable identities and ordered scaling.

```yaml
# statefulset-postgres.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless
  replicas: 3
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
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: "gp2"
        resources:
          requests:
            storage: 20Gi
```

### 3.7 DaemonSets

**DaemonSets** run exactly one Pod per Node — ideal for node-level monitoring, logging, and networking agents.

```yaml
# daemonset-logagent.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule
      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1
          env:
            - name: FLUENT_ELASTICSEARCH_HOST
              value: "elasticsearch.logging.svc.cluster.local"
          resources:
            limits:
              memory: 200Mi
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
```

### 3.8 ConfigMaps & Secrets

#### ConfigMaps (Non-Sensitive Configuration)

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  config.yaml: |
    server:
      host: 0.0.0.0
      port: 8080
    cache:
      ttl: 3600
      maxSize: 1000
```

```yaml
# Using ConfigMap in a Pod
spec:
  containers:
    - name: app
      image: myapp:latest
      envFrom:
        - configMapRef:
            name: app-config
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
  volumes:
    - name: config-vol
      configMap:
        name: app-config
```

#### Secrets (Sensitive Data)

```bash
# Create secret from literal
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='S3cur3P@ssw0rd'

# Create TLS secret
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

```yaml
# secrets.yaml (values must be base64 encoded)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=          # echo -n 'admin' | base64
  password: UzNjdXIzUEBzc3cwcmQ=
```

> ⚠️ **Production Tip:** Use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets Operator](https://external-secrets.io/) for GitOps-safe secret management. Never commit raw Secrets to Git.

### 3.9 Persistent Volumes & Claims

```yaml
# storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
```

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 50Gi
```

```yaml
# Using PVC in a Pod
spec:
  containers:
    - name: app
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-data-pvc
```

### 3.10 Ingress

**Ingress** manages external HTTP/S access to Services, with routing rules, TLS, and host-based routing.

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
        - app.example.com
      secretName: app-tls-secret
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /v1
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 80
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-svc
                port:
                  number: 80
```

### 3.11 RBAC (Role-Based Access Control)

```yaml
# rbac.yaml — Developer role scoped to a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: developer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods/log", "pods/exec"]
    verbs: ["get", "create"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: staging
subjects:
  - kind: User
    name: jane@example.com
    apiGroup: rbac.authorization.k8s.io
  - kind: ServiceAccount
    name: ci-service-account
    namespace: staging
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Verify RBAC permissions
kubectl auth can-i create pods --namespace=staging --as=jane@example.com
kubectl auth can-i delete nodes --as=jane@example.com
```

---

## 4. Real-Time Use Cases & Best Practices

### Use Case 1: Microservices E-Commerce Platform

```yaml
# Complete stack: frontend + API + database with proper isolation
# Apply in order: namespace → secrets → db → api → frontend

# 1. Namespace
---
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce

# 2. API Deployment with all production best practices
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      serviceAccountName: order-service-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
        - name: order-service
          image: myrepo/order-service:1.4.2
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 20
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 40
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: order-service
```

### Use Case 2: Blue-Green Deployment (Zero Downtime)

```bash
# Step 1: Deploy green alongside blue
kubectl apply -f deployment-green.yaml   # new version

# Step 2: Verify green is healthy
kubectl rollout status deployment/app-green
kubectl get pods -l version=green

# Step 3: Switch traffic atomically
kubectl patch service app-svc -p '{"spec":{"selector":{"version":"green"}}}'

# Step 4: Confirm, then remove blue
kubectl delete deployment app-blue
```

### Use Case 3: Canary Release (Gradual Traffic Shift)

```yaml
# canary-deployment.yaml — runs alongside stable with fewer replicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-canary
spec:
  replicas: 1          # 1 canary vs 9 stable = 10% traffic
  selector:
    matchLabels:
      app: api
      track: canary
  template:
    metadata:
      labels:
        app: api
        track: canary
    spec:
      containers:
        - name: api
          image: myrepo/api:3.0.0-beta  # new version
```

```yaml
# The Service selects both stable and canary via shared label
apiVersion: v1
kind: Service
metadata:
  name: api-svc
spec:
  selector:
    app: api    # matches both stable and canary
```

### Best Practices Summary

| Practice | Recommendation |
|----------|---------------|
| **Resource limits** | Always set both `requests` and `limits` |
| **Health probes** | Use readiness + liveness probes on every container |
| **Image tags** | Never use `latest` in production; use immutable digest or SemVer |
| **Replicas** | Minimum 3 replicas for HA workloads |
| **Pod disruption** | Set PodDisruptionBudgets to protect availability during maintenance |
| **Anti-affinity** | Spread Pods across nodes/zones |
| **Non-root** | Run containers as non-root user |
| **Read-only FS** | Set `readOnlyRootFilesystem: true` where possible |
| **Namespaces** | Separate environments and teams into namespaces |
| **Labels** | Use consistent labels (app, version, tier, team) |

---

## 5. Scaling & Auto-Scaling

### Manual Scaling

```bash
kubectl scale deployment api-deployment --replicas=10
```

### Horizontal Pod Autoscaler (HPA)

```yaml
# hpa.yaml — scale based on CPU and memory
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 3
  maxReplicas: 50
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
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 4
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 60
```

### Vertical Pod Autoscaler (VPA)

```yaml
# vpa.yaml — auto-tune resource requests
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  updatePolicy:
    updateMode: "Auto"    # or "Off" for recommendation-only
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 50m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 2Gi
```

### Cluster Autoscaler

```yaml
# cluster-autoscaler.yaml (for AWS EKS)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  template:
    spec:
      containers:
        - name: cluster-autoscaler
          image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
          command:
            - ./cluster-autoscaler
            - --cloud-provider=aws
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
            - --balance-similar-node-groups
            - --skip-nodes-with-system-pods=false
            - --scale-down-delay-after-add=5m
            - --scale-down-unneeded-time=10m
```

### KEDA (Event-Driven Autoscaling)

```yaml
# keda-scaledobject.yaml — scale based on queue length
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker-scaledobject
spec:
  scaleTargetRef:
    name: worker-deployment
  minReplicaCount: 0    # Scale to zero when idle!
  maxReplicaCount: 100
  triggers:
    - type: aws-sqs-queue
      metadata:
        queueURL: https://sqs.us-east-1.amazonaws.com/123456/my-queue
        queueLength: "5"      # target messages per pod
        awsRegion: us-east-1
```

### Pod Disruption Budget

```yaml
# pdb.yaml — ensure availability during node drains
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 2    # or use maxUnavailable: 1
  selector:
    matchLabels:
      app: api
```

---

## 6. Networking

### Network Policies (Micro-Segmentation)

```yaml
# netpol-deny-all.yaml — default deny, then allow explicitly
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# netpol-allow-api.yaml — allow frontend → api only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### DNS & Service Discovery

```bash
# Kubernetes DNS format
<service-name>.<namespace>.svc.cluster.local

# Example lookups from within a pod
curl http://backend-svc.production.svc.cluster.local:8080/api
nslookup postgres.production.svc.cluster.local

# StatefulSet pod DNS
postgres-0.postgres-headless.production.svc.cluster.local
postgres-1.postgres-headless.production.svc.cluster.local
```

---

## 7. Observability — Logging, Metrics & Tracing

### Prometheus & Grafana Stack

```bash
# Install via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=securepassword \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

```yaml
# serviceMonitor.yaml — scrape your app's metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: api
  namespaceSelector:
    matchNames:
      - production
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### Centralized Logging with EFK Stack

```bash
# Install Elasticsearch + Fluentd + Kibana
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch --namespace logging --create-namespace
helm install kibana elastic/kibana --namespace logging
```

```yaml
# fluentd-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      <parse>
        @type json
      </parse>
    </source>
    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch.logging.svc.cluster.local
      port 9200
      index_name kubernetes
    </match>
```

### Distributed Tracing with Jaeger

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm install jaeger jaegertracing/jaeger \
  --namespace tracing \
  --create-namespace \
  --set allInOne.enabled=true
```

---

## 8. Security Hardening

### Pod Security Standards

```yaml
# Enforce restricted policy at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Secure Pod Spec Template

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
```

### Image Scanning with Trivy

```bash
# Scan an image before deploying
trivy image myrepo/api:2.1.0 --severity HIGH,CRITICAL

# Scan a running cluster
trivy k8s --report summary cluster

# Integrate in CI pipeline
trivy image --exit-code 1 --severity CRITICAL myrepo/api:latest
```

### Admission Controllers (OPA/Gatekeeper)

```yaml
# gatekeeper-constraint.yaml — enforce required labels
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: RequiredLabels
metadata:
  name: must-have-team-label
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
  parameters:
    labels:
      - key: team
      - key: app
```

---

## 9. CI/CD Integration

### GitHub Actions — Build & Deploy

```yaml
# .github/workflows/deploy.yaml
name: Build and Deploy to Kubernetes

on:
  push:
    branches: [main]

env:
  IMAGE_NAME: myrepo/api
  DEPLOYMENT: api-deployment
  NAMESPACE: production

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build & Push Docker Image
        run: |
          docker build -t $IMAGE_NAME:${{ github.sha }} .
          docker push $IMAGE_NAME:${{ github.sha }}

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/$DEPLOYMENT \
            api=$IMAGE_NAME:${{ github.sha }} \
            -n $NAMESPACE
          kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=5m

      - name: Rollback on failure
        if: failure()
        run: kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
```

### ArgoCD GitOps Setup

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/k8s-manifests
    targetRevision: main
    path: apps/production/api
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true         # Remove resources deleted from Git
      selfHeal: true      # Correct drift automatically
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

---

## 10. Troubleshooting & Common Issues

### Diagnostic Cheat Sheet

```bash
# ── POD ISSUES ──────────────────────────────────────────────
# Get full Pod events and status
kubectl describe pod <pod-name> -n <namespace>

# Check logs (current and previous crash)
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> --previous

# Stream logs in real-time
kubectl logs -f <pod-name>

# Get logs from all pods of a deployment
kubectl logs -l app=api --all-containers=true --since=1h

# ── EXEC & DEBUG ────────────────────────────────────────────
# Shell into a running pod
kubectl exec -it <pod-name> -- /bin/bash

# Ephemeral debug container (no shell in image?)
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# ── NODES ───────────────────────────────────────────────────
kubectl describe node <node-name>
kubectl top nodes
kubectl get events --sort-by='.lastTimestamp' -A

# ── RESOURCE USAGE ──────────────────────────────────────────
kubectl top pods -n production --sort-by=memory
kubectl top nodes

# ── NETWORKING ──────────────────────────────────────────────
# Test DNS resolution inside a pod
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Test connectivity between pods
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl http://api-svc.production
```

### Common Issues & Fixes

| Status | Cause | Fix |
|--------|-------|-----|
| `Pending` | Insufficient resources | Scale cluster or reduce resource requests |
| `Pending` | No matching nodes (affinity) | Review node selectors/taints/tolerations |
| `CrashLoopBackOff` | App crash on start | Check logs with `--previous`; fix app or probe timing |
| `ImagePullBackOff` | Wrong image name/tag or auth | Verify image exists; check `imagePullSecrets` |
| `OOMKilled` | Memory limit exceeded | Increase `limits.memory` or fix memory leak |
| `Evicted` | Node memory/disk pressure | Increase node capacity; add `PriorityClass` |
| `Terminating` forever | Finalizer stuck | `kubectl patch pod <pod> -p '{"metadata":{"finalizers":[]}}' --type=merge` |
| `0/3 nodes available` | Taint on all nodes | Add toleration or untaint a node |
| `CreateContainerError` | Mount failure (PVC, CM) | Verify volume references exist in the same namespace |

### Port-Forwarding for Local Debugging

```bash
# Forward a Service port to localhost
kubectl port-forward svc/api-svc 8080:80 -n production

# Forward a specific Pod
kubectl port-forward pod/api-deployment-abc123 9090:9090 -n production

# Forward Grafana dashboard locally
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring
```

### Checking Resource Quotas & Limits

```bash
kubectl describe resourcequota -n staging
kubectl describe limitrange -n staging
kubectl get events -n production --field-selector reason=FailedScheduling
```

### etcd Backup & Restore (Self-Managed Clusters)

```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify snapshot
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table

# Restore
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir /var/lib/etcd-restored
```

---

## 11. Helm — Kubernetes Package Manager

### Basic Helm Workflow

```bash
# Add and search repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo redis

# Install a chart
helm install my-redis bitnami/redis \
  --namespace caching \
  --create-namespace \
  --values redis-values.yaml

# List, upgrade, rollback
helm list -A
helm upgrade my-redis bitnami/redis --values redis-values.yaml
helm rollback my-redis 1
helm uninstall my-redis -n caching
```

### Creating a Custom Helm Chart

```bash
helm create my-app-chart
```

```
my-app-chart/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # Template helper functions
│   └── NOTES.txt
└── charts/             # Sub-chart dependencies
```

```yaml
# values.yaml
replicaCount: 3
image:
  repository: myrepo/api
  tag: "1.0.0"
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

```bash
# Lint, dry-run, and install
helm lint my-app-chart/
helm template my-app-chart/ --values production-values.yaml  # render locally
helm install my-app my-app-chart/ --values production-values.yaml --dry-run
helm install my-app my-app-chart/ --values production-values.yaml -n production
```

---

## 12. Additional Resources & References

### Official Documentation

- [Kubernetes Official Docs](https://kubernetes.io/docs/) — Start here for authoritative reference
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) — Essential command reference
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/) — Complete API spec
- [Kubernetes GitHub](https://github.com/kubernetes/kubernetes) — Source code and changelogs

### CNCF Ecosystem Tools

| Tool | Category | Use Case |
|------|----------|----------|
| [Helm](https://helm.sh) | Package Manager | Deploy complex apps with templates |
| [ArgoCD](https://argo-cd.readthedocs.io) | GitOps CD | Declarative continuous delivery |
| [Flux](https://fluxcd.io) | GitOps CD | Lightweight GitOps operator |
| [Prometheus](https://prometheus.io) | Metrics | Time-series monitoring |
| [Grafana](https://grafana.com) | Dashboards | Metrics visualization |
| [Jaeger](https://www.jaegertracing.io) | Tracing | Distributed request tracing |
| [Istio](https://istio.io) | Service Mesh | mTLS, traffic management, observability |
| [Linkerd](https://linkerd.io) | Service Mesh | Lightweight zero-config service mesh |
| [Cert-Manager](https://cert-manager.io) | TLS | Automatic certificate provisioning |
| [KEDA](https://keda.sh) | Autoscaling | Event-driven autoscaling |
| [Falco](https://falco.org) | Security | Runtime threat detection |
| [OPA/Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) | Policy | Admission control policies |
| [Velero](https://velero.io) | Backup | Cluster backup and restore |
| [Crossplane](https://www.crossplane.io) | IaC | Provision cloud resources via K8s |

### Learning Paths

- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — Deep dive into K8s internals
- [CKAD Exam Prep](https://github.com/dgkanatsios/CKAD-exercises) — Certified Kubernetes Application Developer exercises
- [CKA Exam Prep](https://github.com/walidshaari/Kubernetes-Certified-Administrator) — Certified Kubernetes Administrator exercises
- [KodeKloud Labs](https://kodekloud.com/courses/kubernetes-for-the-absolute-beginners-hands-on/) — Hands-on browser labs
- [Killer.sh](https://killer.sh) — Official CKAD/CKA exam simulator

### Community

- [Kubernetes Slack](https://kubernetes.slack.com) — #kubernetes-users, #kubernetes-novice
- [CNCF Community](https://community.cncf.io) — Local meetups and events
- [Stack Overflow — kubernetes tag](https://stackoverflow.com/questions/tagged/kubernetes)
- [Reddit r/kubernetes](https://www.reddit.com/r/kubernetes/)

---

## Quick Reference Card

```bash
# ─── CONTEXT ───────────────────────────────────────────────
kubectl config get-contexts                    # list clusters
kubectl config use-context <context>           # switch cluster

# ─── INSPECT ───────────────────────────────────────────────
kubectl get all -n <ns>                        # all resources
kubectl get pods -A --sort-by=.metadata.name   # all pods sorted
kubectl describe <resource> <name> -n <ns>     # full details
kubectl get events -n <ns> --sort-by=.lastTimestamp

# ─── APPLY / DELETE ────────────────────────────────────────
kubectl apply -f manifest.yaml                 # apply or update
kubectl delete -f manifest.yaml                # delete by manifest
kubectl delete pod <name> --grace-period=0     # force delete

# ─── SCALE & ROLLOUT ───────────────────────────────────────
kubectl scale deploy <name> --replicas=5
kubectl rollout status deploy/<name>
kubectl rollout undo deploy/<name>
kubectl rollout history deploy/<name>

# ─── DEBUG ─────────────────────────────────────────────────
kubectl logs <pod> -f --tail=100               # stream logs
kubectl exec -it <pod> -- bash                 # shell into pod
kubectl port-forward svc/<svc> 8080:80         # local port forward
kubectl top pods --sort-by=cpu -n <ns>         # resource usage

# ─── LABEL & ANNOTATE ──────────────────────────────────────
kubectl label pod <pod> env=prod               # add label
kubectl get pods -l app=api,env=prod           # filter by label
kubectl annotate deploy <name> kubernetes.io/change-cause="v2.1.0"
```

---

> 📌 **Maintained By:** Platform Engineering Team  
> 📅 **Last Updated:** 2025  
> 🔖 **Kubernetes Version:** 1.29+  
> 📝 **License:** MIT
