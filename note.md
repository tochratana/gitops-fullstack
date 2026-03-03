# 📘 GitOps Fullstack Architecture — Learning Notes

> **Project:** `gitops-fullstack`
> **Stack:** Next.js (Frontend) + Spring Boot (Backend) + PostgreSQL (Database)
> **Deployment:** Kubernetes via Helm + ArgoCD GitOps

---

## 📁 Project Structure

```
gitops-fullstack/
├── charts/
│   ├── library/          # Shared Helm helper templates
│   ├── postgres/         # PostgreSQL sub-chart
│   ├── backend/          # Spring Boot API sub-chart
│   ├── frontend/         # Next.js UI sub-chart
│   └── full-stack-app/   # Parent "umbrella" chart — deploys all above
├── environments/
│   ├── dev/values.yaml   # Dev environment overrides
│   └── prod/values.yaml  # Prod environment overrides
└── push.sh               # CI/CD helper script
```

---

## 🧩 How Many Services, Deployments, Ingress?

When ArgoCD deploys the `full-stack-app` umbrella chart, Kubernetes creates:

| Resource | Name (example release: `full-stack`) | Description |
|---|---|---|
| **Deployment** | `full-stack-frontend` | Runs Next.js container (port 3000) |
| **Deployment** | `full-stack-backend` | Runs Spring Boot container (port 8080) |
| **Deployment** | `full-stack-postgres` | Runs PostgreSQL container (port 5432) |
| **Service** | `full-stack-frontend` | ClusterIP — internal access to frontend |
| **Service** | `full-stack-backend` | ClusterIP — internal access to backend |
| **Service** | `full-stack-postgres` | ClusterIP — internal access to postgres |
| **Ingress** | `full-stack-ingress` | Public entry point via nginx |
| **PVC** | `full-stack-postgres-pvc` | Persistent storage claim for postgres |
| **Secret** | `full-stack-postgres-secret` | Stores DB username & password |
| **ConfigMap** | `full-stack-backend-config` | Stores backend env vars |

**Total: 3 Deployments, 3 Services, 1 Ingress, 1 PVC, 1 Secret, 1 ConfigMap**

---

## 🔗 How Services Communicate With Each Other

```
Browser / User
     │  HTTPS (443)
     ▼
[ Ingress: full-stack-ingress ]  ← nginx IngressController
     │
     ├── path: /      → Service: full-stack-frontend :3000
     │                       │
     │                       ▼
     │              Pod: Next.js (frontend)
     │
     └── path: /api   → Service: full-stack-backend :8080
                              │
                              ▼
                     Pod: Spring Boot (backend)
                              │
                              │ JDBC (TCP 5432)
                              ▼
                     Service: full-stack-postgres :5432
                              │
                              ▼
                     Pod: PostgreSQL (database)
```

### Step-by-step Communication Flow

1. **User opens browser** → hits `https://full-stack-dpl.tochratana.com`
2. **Ingress** receives the request and routes based on the URL path:
   - `/` → forwards to `full-stack-frontend` service → Next.js pod
   - `/api` → forwards to `full-stack-backend` service → Spring Boot pod
3. **Frontend (Next.js)** uses `NEXT_PUBLIC_API_URL: "/api"` — any API call goes to `/api/*` which the Ingress routes to the backend
4. **Backend (Spring Boot)** reads `SPRING_DATASOURCE_URL` env var:
   ```
   jdbc:postgresql://full-stack-postgres:5432/blog_db
   ```
   This DNS name `full-stack-postgres` resolves to the `full-stack-postgres` ClusterIP Service
5. **PostgreSQL Service** forwards traffic to the PostgreSQL pod
6. The backend reads DB credentials from `full-stack-postgres-secret` (username + password)

> 💡 **Key concept:** All three services are `ClusterIP` — meaning they are NOT publicly accessible. Only the **Ingress** is the public entry point.

---

## 🚪 Ingress — The Traffic Gateway

```yaml
# From environments/prod/values.yaml
ingress:
  enabled: true
  className: nginx               # Uses nginx IngressController
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"   # Auto TLS cert
    nginx.ingress.kubernetes.io/ssl-redirect: "true"     # Force HTTPS
  hosts:
    - host: full-stack-dpl.tochratana.com
      paths:
        - path: /        → frontend service :3000
        - path: /api     → backend  service :8080
  tls:
    - secretName: full-stack-dpl-tls   # TLS cert stored in K8s Secret
```

- **cert-manager** automatically requests a free TLS certificate from Let's Encrypt
- **ssl-redirect** forces all HTTP traffic to HTTPS
- The Ingress name is `{{ .Release.Name }}-ingress` — so it becomes `full-stack-ingress`

---

## 🤖 What Does ArgoCD Do?

ArgoCD is the **GitOps controller** — it keeps Kubernetes always in sync with your Git repository.

```
GitHub Repo (gitops-fullstack/)
        │
        │  ArgoCD watches this repo
        ▼
 ArgoCD Application
        │
        │  1. Detects changes (new commit)
        │  2. Runs: helm template full-stack-app/ -f environments/prod/values.yaml
        │  3. Compares rendered YAML with current K8s state
        │  4. Applies diff (creates/updates/deletes resources)
        ▼
  Kubernetes Cluster
```

### ArgoCD workflow explained:

| Step | What happens |
|---|---|
| You push to Git | ArgoCD detects the change (polling every ~3 min, or webhook instantly) |
| ArgoCD renders Helm | It runs `helm template` on `full-stack-app/` with prod `values.yaml` |
| Diff check | ArgoCD compares rendered YAML vs. what is running in the cluster |
| Sync | If different → ArgoCD applies the changes (like `kubectl apply`) |
| Self-heal | If someone manually changes K8s, ArgoCD reverts it back to Git state |

### Why GitOps is powerful:
- ✅ **Git = Source of Truth** — the cluster always matches what's in Git
- ✅ **No manual `kubectl apply`** — everything is automated
- ✅ **Audit trail** — every change is a Git commit
- ✅ **Easy rollback** — `git revert` to go back to any previous state

---

## 🐘 PostgreSQL — Deep Dive (PV, PVC, Secret)

This is the most important section. PostgreSQL has persistent storage, which requires understanding three concepts: **StorageClass → PV → PVC**.

### The Storage Chain

```
StorageClass (how to provision)
      │
      │ automatically provisions
      ▼
PersistentVolume / PV  (the actual disk on the node)
      │
      │ bound to
      ▼
PersistentVolumeClaim / PVC  (the request for storage)
      │
      │ mounted into
      ▼
Pod (PostgreSQL container)
      │
      │ writes data to
      ▼
/var/lib/postgresql/data/pgdata  (inside the container)
```

---

### 🟦 StorageClass — "How to Create the Disk"

A StorageClass defines **how** Kubernetes creates persistent volumes. It's like a template/recipe.

```yaml
# Example: local-path StorageClass (used in this project)
kind: StorageClass
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

- When `storageClass: ""` is set in `values.yaml`, Kubernetes uses the **default** StorageClass
- In this project, `local-path` is the default StorageClass (installed via Rancher local-path-provisioner)
- It creates a folder on the **node's disk** to store PostgreSQL data

---

### 🟨 PVC — "I Need Storage" (The Request)

The PVC is created by Helm template `library.pvc` from `charts/library/templates/_pvc.yaml`:

```yaml
# What gets rendered by: library.pvc
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: full-stack-postgres-pvc      # {{ .Release.Name }}-postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce                   # Only one pod can write at a time
  resources:
    requests:
      storage: 10Gi                   # Request 10 GB of storage
  # storageClassName: ""  ← uses cluster default StorageClass
```

**Configured in `postgres/values.yaml`:**
```yaml
persistence:
  enabled: true
  size: 10Gi
  accessModes:
    - ReadWriteOnce
  storageClass: ""   # empty = use cluster default
```

- **ReadWriteOnce (RWO)** = Only 1 node can mount this volume for read/write
- This is correct for PostgreSQL since only 1 pod writes to it

---

### 🟩 PV — "Here Is The Actual Disk" (The Provision)

When a PVC is created, the StorageClass **automatically provisions** a PV:

```yaml
# Auto-created by local-path StorageClass
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvc-xxxxxxxx-xxxx-xxxx-xxxx   # Auto-generated name
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /opt/local-path-provisioner/pvc-xxx/  # Real folder on the node
  claimRef:
    name: full-stack-postgres-pvc   # Bound to this PVC
  persistentVolumeReclaimPolicy: Delete
```

- The PV is **automatically created** — you never write this file manually
- Data is physically stored in a folder on the Kubernetes node

---

### 🟥 Volume Mount — "Attach Storage to Container"

In the postgres template (`postgres.yaml`), the volume is attached to the pod:

```yaml
# Dynamic volumes array built in postgres.yaml template
volumes:
  - name: postgres-storage
    persistentVolumeClaim:
      claimName: full-stack-postgres-pvc   # References the PVC above

# From postgres/values.yaml
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data   # Where PostgreSQL stores its data inside the container
```

**The path `/var/lib/postgresql/data` is where PostgreSQL keeps all database files.** If this is not mounted to a PV, all data is lost when the pod restarts!

---

### 🔐 PostgreSQL Secret — Credentials

The postgres template also creates a Kubernetes Secret for credentials:

```yaml
# Rendered by library.secret in postgres.yaml
apiVersion: v1
kind: Secret
metadata:
  name: full-stack-postgres-secret
type: Opaque
data:
  username: YXBwdXNlcg==    # base64 of "appuser"
  password: U3Ryb25...      # base64 of "StrongP@ssw0rd2026"
```

**Both the backend and postgres pods use this secret:**

```yaml
# In backend.yaml — backend reads DB credentials from the SAME secret
env:
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: full-stack-postgres-secret
        key: username
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: full-stack-postgres-secret
        key: password
```

---

### 🩺 PostgreSQL Health Probes

PostgreSQL uses `pg_isready` command to check if the database is ready:

```yaml
probes:
  liveness:
    exec:
      command: [pg_isready, -U, appuser, -d, blog_db]
    initialDelaySeconds: 30   # Wait 30s before first check (DB takes time to start)
    periodSeconds: 10         # Check every 10s
  readiness:
    exec:
      command: [pg_isready, -U, appuser, -d, blog_db]
    initialDelaySeconds: 5    # First check after 5s
    periodSeconds: 5          # Check every 5s
```

- **Liveness probe** = if this fails, Kubernetes **restarts** the pod
- **Readiness probe** = if this fails, Kubernetes **stops sending traffic** to the pod (removes from Service endpoints)

---

## 🏗️ Library Chart — Shared Templates

The `charts/library/` chart is a **Helm Library Chart** — it has no `templates/` that deploy anything directly. It only provides reusable `define` blocks used by other charts.

| Template | What it does |
|---|---|
| `library.deployment` | Creates a `Deployment` resource |
| `library.service` | Creates a `Service` resource |
| `library.configmap` | Creates a `ConfigMap` resource |
| `library.secret` | Creates a `Secret` resource |
| `library.pvc` | Creates a `PersistentVolumeClaim` |

This way, `backend`, `frontend`, and `postgres` all share the same consistent Deployment/Service structure — no code duplication!

---

## 🔄 Full CI/CD Flow

```
Developer pushes code
        │
        ▼
GitHub Actions / CI Pipeline
        │  - Build Docker image
        │  - Push to DockerHub: tochratana/prod-api:new-tag
        │  - Run push.sh → updates image tag in values.yaml
        │  - Git commit + push to gitops-fullstack repo
        ▼
ArgoCD detects new commit
        │  - Renders Helm chart with new image tag
        │  - Applies to Kubernetes cluster
        ▼
Kubernetes rolling update
        │  - Pulls new image: tochratana/prod-api:new-tag
        │  - Creates new pod with new image
        │  - Old pod is terminated after new pod is ready
        ▼
Users see the new version (zero downtime!)
```

---

## 📊 Environment Values Override Chain

Helm merges values in this order (later = higher priority):

```
charts/postgres/values.yaml       ← lowest priority (defaults)
        +
charts/full-stack-app/values.yaml ← parent chart overrides
        +
environments/prod/values.yaml     ← highest priority (prod overrides)
        =
Final rendered YAML sent to Kubernetes
```

---

## 🧠 Summary — Key Concepts to Remember

| Concept | What it means |
|---|---|
| **ClusterIP Service** | Internal-only access, pods talk to each other via DNS (service name) |
| **Ingress** | The single public entry point, routes traffic by URL path |
| **ArgoCD** | Watches Git, keeps K8s in sync automatically |
| **PV (PersistentVolume)** | The actual storage on the node's disk |
| **PVC (PersistentVolumeClaim)** | A request for storage — K8s binds it to a PV |
| **StorageClass** | Recipe for how to auto-provision PVs |
| **Secret** | Stores sensitive data (passwords) in base64 encoded form |
| **ConfigMap** | Stores non-sensitive config (env vars) |
| **Library Chart** | Helm chart with reusable templates, not deployed directly |
| **Umbrella Chart** | Parent chart (`full-stack-app`) that bundles sub-charts together |
| **Liveness Probe** | If fails → K8s restarts the pod |
| **Readiness Probe** | If fails → K8s stops routing traffic to the pod |
