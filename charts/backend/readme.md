# 📦 Backend Chart Notes

## What This Chart Does
Deploys the **Spring Boot API** (`tochratana/prod-api`) to Kubernetes.
It depends on the shared **library chart** (`charts/library/`) for reusable templates.

---

## Chart Structure

```
charts/backend/
├── Chart.yaml        # Chart metadata + library dependency
├── values.yaml       # All configurable values
├── charts/           # Downloaded library chart (auto by helm dep update)
└── templates/
    └── backend.yaml  # Renders: ConfigMap, Deployment, Service
```

---

## Kubernetes Resources Generated

| Resource   | Name Pattern                  | Purpose                            |
|------------|-------------------------------|------------------------------------|
| ConfigMap  | `<release>-backend-config`    | Static env vars (Spring profile, port, log level) |
| Deployment | `<release>-backend`           | Runs the API container             |
| Service    | `<release>-backend`           | ClusterIP on port 8080 (internal)  |

---

## Key values.yaml Settings

| Field                    | Value                       | Notes                                      |
|--------------------------|-----------------------------|--------------------------------------------|
| `image.repository`       | `tochratana/prod-api`       | Docker Hub image                           |
| `image.tag`              | `01d931c2`                  | Git short SHA — updated by CI/CD pipeline  |
| `image.pullPolicy`       | `Always`                    | Always pull latest on pod restart          |
| `replicaCount`           | `1`                         | Single replica                             |
| `service.type`           | `ClusterIP`                 | Internal only, ingress handles external    |
| `config.SPRING_PROFILES_ACTIVE` | `k8s`              | Activates Kubernetes-specific Spring config|
| `resources.requests`     | 512Mi RAM / 500m CPU        | Minimum guaranteed resources               |
| `resources.limits`       | 1Gi RAM / 1000m CPU         | Maximum allowed resources                  |
| `database.name`          | `blog_db`                   | Used to build the JDBC URL dynamically     |

---

## Database Connection (Dynamic)

These env vars are **injected dynamically** by `backend.yaml` (cannot be in values.yaml
because they use `Release.Name` which is only known at deploy time):

```
SPRING_DATASOURCE_URL      = jdbc:postgresql://<release>-postgres:5432/blog_db
SPRING_DATASOURCE_USERNAME → Secret: <release>-postgres-secret  key: username
SPRING_DATASOURCE_PASSWORD → Secret: <release>-postgres-secret  key: password
```

> The hostname `<release>-postgres` resolves via **Kubernetes internal DNS** — 
> it matches the Service name created by the postgres chart.

---

## Health Probes

```
Startup Probe   /actuator/health/liveness
  → delay 30s, retry every 10s, up to 12 failures = 150s max startup time
  → Spring Boot is slow to start, this prevents premature restarts

Liveness Probe  /actuator/health/liveness
  → every 10s, fail 3× → pod RESTARTS

Readiness Probe /actuator/health/readiness
  → every 5s, fail 3× → pod removed from Service (no traffic), not restarted
```

---

## How Library Templates Work

The `backend.yaml` template calls 3 library helpers:

```
library.configmap  →  creates the ConfigMap from values.config
library.deployment →  creates the Deployment (with dynamic env injected)
library.service    →  creates the Service from values.service
```

This pattern avoids copy-pasting the same Deployment/Service YAML in every chart.
The frontend chart uses the exact same library templates.

---

## Full Flow

```
ArgoCD watches Git repo
    │
    ▼
Helm renders backend chart
    │
    ├──► ConfigMap  : static Spring env vars
    ├──► Deployment : pulls image, mounts config + secrets, runs health probes
    └──► Service    : ClusterIP listens on 8080
                          │
                     Ingress routes /api/* → <release>-backend:8080
```

---

## CI/CD Integration

The `image.tag` in `values.yaml` is automatically updated by the GitHub Actions pipeline
after a successful Docker build:

```yaml
# values.yaml line updated by CI:
image:
  tag: "<new-git-sha>"   # ← pipeline writes this on every merge to main
```

ArgoCD detects the change in Git and rolls out the new image automatically.
