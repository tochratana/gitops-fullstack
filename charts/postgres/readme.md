# 🐘 Postgres Chart Notes

## What This Chart Does
Deploys **PostgreSQL 17 (alpine)** to Kubernetes with persistent storage.
It is the most complex chart — it manages a Secret, PVC, Deployment, and Service.
The backend connects to it using the credentials stored in the Secret.

---

## Chart Structure

```
charts/postgres/
├── Chart.yaml        # Chart metadata (appVersion: 15.0) + library dependency
├── values.yaml       # Config: image, auth, persistence, probes, resources
├── charts/           # Downloaded library chart (auto by helm dep update)
└── templates/
    └── postgres.yaml # Renders: Secret, PVC, Deployment, Service
```

---

## Kubernetes Resources Generated

| Resource              | Name Pattern                 | Purpose                                          |
|-----------------------|------------------------------|--------------------------------------------------|
| Secret                | `<release>-postgres-secret`  | Stores DB username + password (base64 encoded)   |
| PersistentVolumeClaim | `<release>-postgres-pvc`     | Requests 10Gi disk storage for DB data           |
| Deployment            | `<release>-postgres`         | Runs the PostgreSQL container                    |
| Service               | `<release>-postgres`         | ClusterIP on port 5432 (internal only)           |

---

## Key values.yaml Settings

| Field                    | Value                   | Notes                                              |
|--------------------------|-------------------------|----------------------------------------------------|
| `image.repository`       | `postgres`              | Official Docker Hub PostgreSQL image               |
| `image.tag`              | `17-alpine`             | Alpine = smaller image size                        |
| `image.pullPolicy`       | `IfNotPresent`          | Don't re-pull if already on node                   |
| `replicaCount`           | `1`                     | Single instance (no HA — not recommended for prod) |
| `service.type`           | `ClusterIP`             | Internal only — DB is never exposed outside        |
| `auth.username`          | `appuser`               | PostgreSQL user created on startup                 |
| `auth.database`          | `blog_db`               | Database name created on startup                   |
| `auth.password`          | `StrongP@ssw0rd2026`    | ⚠️ Change this for production!                    |
| `persistence.enabled`    | `true`                  | Enable PVC for data durability                     |
| `persistence.size`       | `10Gi`                  | 10 gigabytes of storage requested                  |
| `persistence.accessModes`| `ReadWriteOnce`         | Only ONE node can mount this volume at a time      |
| `persistence.storageClass`| `""` (empty)           | Uses cluster default storage class (e.g. local-path)|

---

## Secret — How Credentials Are Stored

The template creates a Kubernetes Secret automatically:

```yaml
# Generated Secret (simplified):
apiVersion: v1
kind: Secret
metadata:
  name: <release>-postgres-secret
type: Opaque
data:
  username: YXBwdXNlcg==          # "appuser"  base64 encoded
  password: U3Ryb25nUE...         # "StrongP@ssw0rd2026" base64 encoded
```

> 🔐 Base64 is NOT encryption — it is just encoding.
> Anyone with kubectl access can decode it with: `kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d`
> For real production security, use **Sealed Secrets** or **Vault**.

This Secret is then consumed by:
- **The postgres pod** → via `POSTGRES_USER` and `POSTGRES_PASSWORD` env vars
- **The backend pod** → via `SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD`

---

## PVC — Persistent Volume Claim (Disk Storage)

```yaml
# Generated PVC (simplified):
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <release>-postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce      # one node at a time
  resources:
    requests:
      storage: 10Gi      # request 10GB from the storage class
```

### How PV/PVC works:

```
PVC (what you ask for)          PV (what the cluster provides)
┌────────────────────┐          ┌────────────────────────────┐
│ I need 10Gi disk   │ ──────►  │ Here's a 10Gi volume on    │
│ ReadWriteOnce      │  binds   │ the node's local disk      │
│ any storage class  │          │ (K3s: local-path provisioner│
└────────────────────┘          └────────────────────────────┘
         │
         ▼
  Mounted into the postgres pod at:
  /var/lib/postgresql/data/pgdata
```

> Without PVC, all database data is **lost** every time the pod restarts.
> With PVC, data **survives** pod restarts, crashes, and redeployments.

---

## Dynamic Env Vars Injected by Template

Like the backend, the postgres template injects env vars dynamically because
they reference `Release.Name` which is only known at deploy time:

```
POSTGRES_DB       = blog_db         (from values.auth.database)
POSTGRES_USER     → Secret: <release>-postgres-secret  key: username
POSTGRES_PASSWORD → Secret: <release>-postgres-secret  key: password
PGDATA            = /var/lib/postgresql/data/pgdata     (data subdirectory)
```

> 💡 **Why `PGDATA` points to a subdirectory?**  
> PostgreSQL requires the data directory to be empty on first start.
> When K8s mounts the PVC at `/var/lib/postgresql/data`, it may create a
> `lost+found` folder there. Using `/pgdata` as a subdirectory avoids this conflict.

---

## Health Probes — Uses `pg_isready`

Unlike frontend/backend (which use HTTP), PostgreSQL uses a **CLI command probe**:

```
Liveness Probe (exec):
  pg_isready -U appuser -d blog_db
  → delay 30s, every 10s → if fails, pod RESTARTS

Readiness Probe (exec):
  pg_isready -U appuser -d blog_db
  → delay 5s, every 5s → if fails, removed from Service (no traffic)
```

`pg_isready` is a built-in PostgreSQL utility that checks if the server
is accepting connections. It exits with code 0 if ready, non-zero if not.

---

## Resources

| Type     | Memory  | CPU    |
|----------|---------|--------|
| Request  | 256Mi   | 250m   |
| Limit    | 512Mi   | 500m   |

Lighter than the backend (Spring Boot) because PostgreSQL is more memory-efficient.

---

## templates/postgres.yaml — Full Resource Generation Flow

```
postgres.yaml
    │
    ├─1─► library.secret      →  Secret:  <release>-postgres-secret
    │         └── username + password (from values.auth, base64 by library)
    │
    ├─2─► library.pvc         →  PVC:     <release>-postgres-pvc
    │         └── 10Gi, ReadWriteOnce (only if persistence.enabled = true)
    │
    ├─3─► library.deployment  →  Deployment: <release>-postgres
    │         ├── image: postgres:17-alpine
    │         ├── env: POSTGRES_DB, POSTGRES_USER (secret), POSTGRES_PASSWORD (secret), PGDATA
    │         ├── volumeMounts: /var/lib/postgresql/data
    │         ├── volumes: bound to <release>-postgres-pvc
    │         └── probes: pg_isready liveness + readiness
    │
    └─4─► library.service     →  Service: <release>-postgres
              └── ClusterIP, port 5432
```

---

## How Backend Connects to Postgres

```
Backend Pod                          Postgres Pod
─────────────────────────────────    ────────────────────────────
SPRING_DATASOURCE_URL =              Service: <release>-postgres
  jdbc:postgresql://                 └── port 5432
    <release>-postgres:5432/               │
    blog_db                ──────────────► PostgreSQL process
SPRING_DATASOURCE_USERNAME                 └── data at /pgdata
  (from same Secret)                             └── PVC → PV
SPRING_DATASOURCE_PASSWORD                             └── physical disk
  (from same Secret)
```

K8s internal DNS resolves `<release>-postgres` to the Service ClusterIP automatically.

---

## ⚠️ Important: Change the Password for Production!

```yaml
# values.yaml line 31 — CHANGE THIS:
auth:
  password: "StrongP@ssw0rd2026"   # ← never use a hardcoded password in production!
```

Better approaches for production:
- Use **Kubernetes Secrets** created separately (not in values.yaml)
- Use **Sealed Secrets** (encrypted secrets committed to Git)
- Use **HashiCorp Vault** + the Vault agent injector
