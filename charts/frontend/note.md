# 🎨 Frontend Chart Notes

## What This Chart Does
Deploys the **Next.js web application** to Kubernetes.
It depends on the same shared **library chart** (`charts/library/`) as the backend.
Much simpler than the backend — no database connection, no secrets needed.

---

## Chart Structure

```
charts/frontend/
├── Chart.yaml        # Chart metadata + library dependency
├── values.yaml       # All configurable values
├── charts/           # Downloaded library chart (auto by helm dep update)
└── templates/
    └── frontend.yaml # Renders: ConfigMap, Deployment, Service (3 lines only!)
```

---

## Kubernetes Resources Generated

| Resource   | Name Pattern                   | Purpose                                  |
|------------|--------------------------------|------------------------------------------|
| ConfigMap  | `<release>-frontend-config`    | NEXT_PUBLIC env vars (API URL, app name) |
| Deployment | `<release>-frontend`           | Runs the Next.js container               |
| Service    | `<release>-frontend`           | ClusterIP on port 3000 (internal)        |

---

## Key values.yaml Settings

| Field                      | Value                | Notes                                               |
|----------------------------|----------------------|-----------------------------------------------------|
| `image.repository`         | `nginx` (default)    | CI/CD overrides this with the real Next.js image    |
| `image.tag`                | `latest` (default)   | CI/CD writes the real git SHA here after each build |
| `image.pullPolicy`         | `IfNotPresent`       | Only pulls if image not already on node             |
| `replicaCount`             | `1`                  | Single replica                                      |
| `ports.containerPort`      | `3000`               | Next.js default port                                |
| `service.type`             | `ClusterIP`          | Internal only, ingress handles external traffic     |
| `service.ports`            | `3000`               | Routes to container port `http`                     |
| `config.NEXT_PUBLIC_API_URL`| `/api`              | Tells browser where to call the backend (relative!) |
| `config.NEXT_PUBLIC_APP_NAME`| `MyApp`            | App name accessible client-side                    |
| `resources`                | `{}` (not set)       | No limits — uncomment if you want to cap resources  |
| `autoscaling.enabled`      | `false`              | Can enable HPA for auto-scaling later               |

---

## ConfigMap — NEXT_PUBLIC env vars

```yaml
config:
  NEXT_PUBLIC_API_URL: "/api"         # relative path → same for all environments
  NEXT_PUBLIC_APP_NAME: "MyApp"
```

> 💡 **Why `NEXT_PUBLIC_*`?** In Next.js, only variables prefixed with `NEXT_PUBLIC_`
> are exposed to the **browser (client-side)**. Without this prefix, the variable only
> exists on the server and the browser never sees it.

> 💡 **Why `/api` (relative path)?** Using a relative URL means the same Docker image
> works in dev, staging, and production — no rebuild needed for different environments!
> The **ingress** handles routing:
> - `/api/*` → backend:8080
> - `/` → frontend:3000

---

## Health Probes — Simple (No Startup Probe)

```
Liveness Probe   GET /   port: 3000
  → Kubernetes checks if the app is alive

Readiness Probe  GET /   port: 3000
  → Kubernetes checks if the app is ready to receive traffic
```

No **startup probe** needed — Next.js starts up much faster than Spring Boot.

---

## templates/frontend.yaml — Only 3 Lines of Logic!

```yaml
{{- include "library.configmap"  (list $ $component (dict "config" $values.config)) }}
---
{{- include "library.deployment" (list $ $component $values) }}
---
{{- include "library.service"    (list $ $component $values) }}
```

No dynamic env injection needed — unlike the backend, the frontend doesn't need
`Release.Name` for database secrets. Everything comes straight from `values.yaml`.

---

## Frontend vs Backend Comparison

| Feature               | Frontend              | Backend                       |
|-----------------------|-----------------------|-------------------------------|
| Image                 | `nginx` (CI override) | `tochratana/prod-api`         |
| Port                  | `3000`                | `8080`                        |
| Database connection   | ❌ None               | ✅ JDBC URL + Secret          |
| Dynamic env injection | ❌ Not needed         | ✅ Yes (Release.Name based)   |
| Startup Probe         | ❌ None               | ✅ 150s grace period          |
| Resource Limits       | ❌ Not set            | ✅ 1Gi RAM, 1 CPU             |
| Secrets               | ❌ None               | ✅ DB username + password     |
| Template complexity   | 3 lines               | 31 lines (dynamic injection)  |

---

## Full Traffic Flow

```
Browser
    │
    ▼
Ingress (nginx-ingress)
    │
    ├── /api/* ──────────► Service: <release>-backend:8080
    │                           └── Spring Boot → PostgreSQL
    │
    └── / ──────────────► Service: <release>-frontend:3000
                              └── Next.js App
                                    └── fetches /api/* (proxied by ingress)
```

The frontend NEVER speaks to the database directly.
It only makes HTTP calls to `/api/*` which the ingress routes to the backend.

---

## CI/CD Integration

After a successful Docker build, the GitHub Actions pipeline updates `image.tag`:

```yaml
# values.yaml line updated by CI:
image:
  repository: tochratana/prod-frontend   # ← set by CI pipeline
  tag: "<new-git-sha>"                   # ← updated on every push to main
```

ArgoCD detects the Git change and automatically deploys the new image to the cluster.
