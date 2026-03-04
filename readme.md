# 🚀 GitOps Fullstack — Helm Chart Repository

A **GitOps-style Helm chart repository** for deploying a fullstack application to Kubernetes via **ArgoCD**.

**Stack:** Next.js (Frontend) · Spring Boot (Backend) · PostgreSQL (Database)

> **Flexible deployment** — deploy the full stack, or any individual service independently.

---

## 📐 Architecture

```
User (Browser)
     │  HTTPS (443)
     ▼
Ingress (full-stack-dpl.tochratana.com)
     ├── /         → Frontend Service (Next.js :3000)
     └── /api      → Backend Service  (Spring Boot :8080)
                           │
                           │ JDBC (TCP 5432)
                           ▼
                    PostgreSQL Service (:5432)
                           │
                    PersistentVolume (10Gi)
```

---

## 📁 Repository Structure

```
gitops-fullstack/
├── charts/
│   ├── library/                 # Shared Helm library templates (deployment, service, configmap, etc.)
│   ├── frontend/                # Sub-chart: Next.js frontend
│   ├── backend/                 # Sub-chart: Spring Boot backend
│   ├── postgres/                # Sub-chart: PostgreSQL database
│   └── full-stack-app/          # 🎯 Umbrella chart — point ArgoCD here
│       ├── Chart.yaml           #    Declares all sub-chart dependencies
│       ├── values.yaml          #    Default values for all sub-charts
│       ├── charts/              #    Packaged sub-charts (.tgz)
│       └── templates/
│           └── ingress.yaml     #    Ingress resource with domain routing
├── environments/
│   ├── dev/values.yaml          # Dev environment overrides
│   └── prod/values.yaml         # Prod environment overrides
├── REQUIREMENTS.md              # Prerequisites & infrastructure checklist
├── CHANGELOG.md                 # Release history
├── push.sh                      # Auto push script
└── readme.md
```

---

## 📋 Requirements

See [**REQUIREMENTS.md**](REQUIREMENTS.md) for the full checklist. In short:

| Requirement | Minimum Version |
|---|---|
| Kubernetes | 1.24+ |
| Helm | v3.0+ |
| kubectl | matching cluster version |
| Nginx Ingress Controller | any |
| cert-manager | v1.0+ |
| ArgoCD | v2.0+ |
| StorageClass | `local-path` or cloud provider |
| Container registry | DockerHub or any private registry |

---

## 🚀 Quick Start: Deploy Full Stack

This deploys **frontend + backend + postgres** together as one ArgoCD application.

### 1. Clone the repo

```bash
git clone https://github.com/<your-org>/gitops-fullstack.git
cd gitops-fullstack
```

### 2. Create the namespace & postgres secret

```bash
kubectl create namespace fullstack

kubectl create secret generic postgres-secret \
  --from-literal=username=appuser \
  --from-literal=password='<your-secure-password>' \
  -n fullstack
```

### 3. Update Helm dependencies

```bash
helm dependency update ./charts/full-stack-app
```

### 4. Configure your values

Edit `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  enabled: true
  image:
    repository: tochratana/prod-ui    # ← your frontend image
    tag: "70e14a03"                    # ← your image tag
  config:
    NEXT_PUBLIC_API_URL: "/api"
    NEXT_PUBLIC_APP_NAME: "MyApp"

backend:
  enabled: true
  image:
    repository: tochratana/prod-api   # ← your backend image
    tag: "84112e4b"                    # ← your image tag

postgres:
  enabled: true
```

### 5. (Option A) Deploy via ArgoCD

Point ArgoCD to this repo:

| Field | Value |
|---|---|
| **Repository URL** | `https://github.com/<your-org>/gitops-fullstack` |
| **Revision** | `main` |
| **Path** | `charts/full-stack-app` |
| **Namespace** | `fullstack` |
| **Values File** | `environments/prod/values.yaml` (optional) |

### 5. (Option B) Deploy via Helm CLI

```bash
# Dry run first
helm template my-release ./charts/full-stack-app \
  -f environments/prod/values.yaml

# Install
helm install my-release ./charts/full-stack-app \
  -n fullstack \
  -f environments/prod/values.yaml
```

---

## 🎯 Deploy Individual Services

Each sub-chart can be enabled/disabled independently by setting `<component>.enabled: true/false` in the umbrella chart's `values.yaml`.

---

### Deploy Frontend Only

Set in `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  enabled: true
  image:
    repository: tochratana/prod-ui
    tag: "70e14a03"
  config:
    NEXT_PUBLIC_API_URL: "https://your-api-domain.com/api"  # ← full external API URL
    NEXT_PUBLIC_APP_NAME: "MyApp"

backend:
  enabled: false    # ← disabled

postgres:
  enabled: false    # ← disabled
```

> **Note:** When backend is disabled, set `NEXT_PUBLIC_API_URL` to the **full external URL** of your API instead of the relative `/api` path.

**Frontend environment variables:**

| Variable | Where Set | Default | Description |
|---|---|---|---|
| `NEXT_PUBLIC_API_URL` | ConfigMap | `/api` | API base URL. Use `/api` (relative) when backend is co-deployed, or full URL when external |
| `NEXT_PUBLIC_APP_NAME` | ConfigMap | `MyApp` | Application display name |

```bash
helm install my-release ./charts/full-stack-app -n fullstack
```

---

### Deploy Backend Only

Set in `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  enabled: false    # ← disabled

backend:
  enabled: true
  image:
    repository: tochratana/prod-api
    tag: "84112e4b"
  config:
    SPRING_PROFILES_ACTIVE: "k8s"
    LOGGING_LEVEL_COM_EXAMPLE: "DEBUG"
    SERVER_PORT: "8080"
  database:
    name: blog_db     # ← your database name

postgres:
  enabled: true       # ← keep enabled if you need the DB
```

> **Note:** The backend **requires** a PostgreSQL database. Either deploy the `postgres` sub-chart together, or point to an **external** PostgreSQL by customizing the backend template.

**Backend environment variables:**

| Variable | Where Set | Default | Description |
|---|---|---|---|
| `SPRING_PROFILES_ACTIVE` | ConfigMap | `k8s` | Active Spring profile |
| `SERVER_PORT` | ConfigMap | `8080` | Server listen port |
| `LOGGING_LEVEL_COM_EXAMPLE` | ConfigMap | `DEBUG` | Application log level |
| `SPRING_DATASOURCE_URL` | Auto-injected (template) | `jdbc:postgresql://<release>-postgres:5432/<db_name>` | JDBC connection URL — built from release name + `database.name` |
| `SPRING_DATASOURCE_USERNAME` | Secret (`postgres-secret`) | `appuser` | Database username |
| `SPRING_DATASOURCE_PASSWORD` | Secret (`postgres-secret`) | — | Database password |

---

### Deploy PostgreSQL Only

Set in `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  enabled: false    # ← disabled

backend:
  enabled: false    # ← disabled

postgres:
  enabled: true
  auth:
    username: appuser
    database: blog_db
    password: "YourStrongPassword"
  persistence:
    enabled: true
    size: 10Gi
    storageClass: ""    # uses cluster default StorageClass
```

**PostgreSQL configuration:**

| Config | Where Set | Default | Description |
|---|---|---|---|
| `auth.username` | values.yaml → Secret | `appuser` | PostgreSQL username |
| `auth.password` | values.yaml → Secret | `StrongP@ssw0rd2026` | PostgreSQL password (**change this!**) |
| `auth.database` | values.yaml → env | `blog_db` | Database name to create |
| `persistence.size` | values.yaml → PVC | `10Gi` | Persistent volume size |
| `persistence.storageClass` | values.yaml → PVC | `""` (cluster default) | StorageClass to use (`""` = default, or `local-path`, `gp2`, etc.) |
| `persistence.accessModes` | values.yaml → PVC | `ReadWriteOnce` | Volume access mode |

**PostgreSQL auto-injected env vars (set by template, not by user):**

| Variable | Source | Description |
|---|---|---|
| `POSTGRES_DB` | `auth.database` value | Database to create on boot |
| `POSTGRES_USER` | Secret `username` key | Superuser for the database |
| `POSTGRES_PASSWORD` | Secret `password` key | Superuser password |
| `PGDATA` | Hardcoded | `/var/lib/postgresql/data/pgdata` — data directory |

---

## 🌍 Environments

Override values per environment using files in `environments/`:

| Environment | File | Use Case |
|---|---|---|
| **dev** | `environments/dev/values.yaml` | Development — uses `dev-latest` tags, smaller PVC, debug logging |
| **prod** | `environments/prod/values.yaml` | Production — pinned image tags, larger PVC, INFO logging, TLS |

### How to use

```bash
# Dev
helm template my-release ./charts/full-stack-app -f environments/dev/values.yaml

# Prod
helm template my-release ./charts/full-stack-app -f environments/prod/values.yaml
```

**Values merge order** (later overrides earlier):
```
charts/<component>/values.yaml      ← defaults (lowest priority)
         +
charts/full-stack-app/values.yaml   ← umbrella chart overrides
         +
environments/<env>/values.yaml      ← environment overrides (highest priority)
```

---

## 🔧 Updating Image Tags

Image tags live in `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  image:
    repository: tochratana/prod-ui
    tag: "70e14a03"         # ← update this

backend:
  image:
    repository: tochratana/prod-api
    tag: "84112e4b"         # ← update this
```

After editing, push with the auto script:

```bash
./push.sh "feat: update frontend image to v2.0"
```

ArgoCD will automatically detect the change and roll out new pods.

---

## ⚡ Auto Push Script (`push.sh`)

One-command workflow: updates Helm deps → stages → commits → pushes.

```bash
# First time: make it executable
chmod +x push.sh

# Push with default timestamped message
./push.sh

# Push with custom commit message
./push.sh "feat: update frontend image tag"
```

---

## 🔀 Fork & Adapt for Your Own Service

Want to use this repo as a template for **your own** fullstack app? Follow these steps:

### Step 1: Fork / Clone

```bash
git clone https://github.com/<your-org>/gitops-fullstack.git my-gitops
cd my-gitops
```

### Step 2: Change image repositories

Edit `charts/full-stack-app/values.yaml`:

```yaml
frontend:
  image:
    repository: your-dockerhub/your-frontend   # ← your image
    tag: "latest"

backend:
  image:
    repository: your-dockerhub/your-backend     # ← your image
    tag: "latest"
```

### Step 3: Change the domain

Edit the ingress section in `charts/full-stack-app/values.yaml`:

```yaml
ingress:
  hosts:
    - host: your-domain.com                     # ← your domain
      paths:
        - path: /
          pathType: Prefix
          service: frontend
          port: 3000
        - path: /api
          pathType: Prefix
          service: backend
          port: 8080                             # ← change if your backend uses a different port
  tls:
    - secretName: your-tls-secret               # ← your TLS secret name
      hosts:
        - your-domain.com
```

### Step 4: Change database name

```yaml
backend:
  database:
    name: your_db_name                          # ← your database

postgres:
  auth:
    username: your_user
    database: your_db_name
    password: "YourSecurePassword"
```

### Step 5: Swap Spring Boot for another backend

The backend chart is generic — it creates a `Deployment`, `Service`, and `ConfigMap`. To use a **different** backend (Node.js, Go, Python, etc.):

1. **Change the image:**
   ```yaml
   backend:
     image:
       repository: your-dockerhub/your-node-api
       tag: "latest"
   ```

2. **Change the port** (if not 8080):
   ```yaml
   backend:
     ports:
       - name: http
         containerPort: 3001       # ← your backend port
     service:
       ports:
         - name: http
           port: 3001              # ← match container port
           targetPort: http
   ```
   Also update the ingress path port:
   ```yaml
   ingress:
     hosts:
       - host: your-domain.com
         paths:
           - path: /api
             service: backend
             port: 3001            # ← match service port
   ```

3. **Change config env vars** (remove Spring-specific, add yours):
   ```yaml
   backend:
     config:
       NODE_ENV: "production"      # ← your env vars
       PORT: "3001"
   ```

4. **Change or remove health probes** (if not using Spring Actuator):
   ```yaml
   backend:
     probes:
       liveness:
         httpGet:
           path: /health           # ← your health endpoint
           port: http
       readiness:
         httpGet:
           path: /ready
           port: http
   ```

5. **If your backend doesn't need PostgreSQL**, disable it:
   ```yaml
   postgres:
     enabled: false
   ```
   And remove the `database` and DB env vars from the backend template.

### Step 6: Add a new sub-chart

To add another service (e.g., a Redis cache):

1. Create `charts/redis/` with `Chart.yaml`, `values.yaml`, and `templates/redis.yaml`
2. Add it as a dependency in `charts/full-stack-app/Chart.yaml`:
   ```yaml
   dependencies:
     - name: redis
       version: 0.1.0
       repository: file://../redis
       condition: redis.enabled
   ```
3. Run `helm dependency update ./charts/full-stack-app`
4. Add `redis:` section to `charts/full-stack-app/values.yaml`

### Step 7: Update Helm deps & push

```bash
helm dependency update ./charts/full-stack-app
./push.sh "feat: adapted for my-service"
```

---

## 🔑 Secrets Management

The PostgreSQL chart auto-generates a Kubernetes Secret from `postgres.auth` values. However, for **production**, create the secret manually **before** deploying:

```bash
kubectl create secret generic postgres-secret \
  --from-literal=username=appuser \
  --from-literal=password='<your-secure-password>' \
  -n fullstack
```

> **Recommended:** Use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets Operator](https://external-secrets.io/) for production secret management instead of storing passwords in `values.yaml`.


## 📋 Troubleshooting

| Problem | Solution |
|---|---|
| ArgoCD shows `ComparisonError` | Run `helm dependency update ./charts/full-stack-app` and push |
| `helm template` fails | Run `helm lint ./charts/full-stack-app` to find template errors |
| Pods not starting | `kubectl describe pod <name> -n fullstack` — check image pull errors, resource limits |
| Ingress not working | Verify nginx-ingress controller is installed: `kubectl get pods -n ingress-nginx` |
| TLS certificate not issued | Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager` |
| Database connection refused | Ensure postgres pod is running and secret name matches `<release>-postgres-secret` |
| `.tgz` files missing | Run `helm dependency update ./charts/full-stack-app` |
| 502 Bad Gateway | Check backend pod logs and readiness probe — the backend may still be starting |
| PVC stuck in `Pending` | Verify a default StorageClass exists: `kubectl get sc` |

---

## 📄 License

This project is open source. Feel free to fork and adapt for your own use.