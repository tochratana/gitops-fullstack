# 🏗️ Full-Stack-App Chart Notes

## What This Chart Does
The **umbrella chart** — bundles frontend, backend, and postgres into a single deployable unit.
ArgoCD points to **this chart only** and it deploys everything automatically.
Also the only chart that creates the **Ingress** resource.

---

## Chart Structure

```
charts/full-stack-app/
├── Chart.yaml        # Declares frontend, backend, postgres as dependencies
├── values.yaml       # Master config — overrides all sub-chart values
├── charts/           # Packaged sub-charts (.tgz files from helm dep update)
└── templates/
    ├── ingress.yaml  # Ingress routing rules (/ → frontend, /api → backend)
    └── frontend.yaml # Empty placeholder file
```

---

## Chart.yaml — 3 Sub-chart Dependencies

```yaml
dependencies:
  - name: frontend   condition: frontend.enabled   # toggle with frontend.enabled: false
  - name: backend    condition: backend.enabled
  - name: postgres   condition: postgres.enabled
```

> 💡 The `condition:` field lets you **disable** any service. For example:
> set `postgres.enabled: false` if you use an external managed database.

---

## Kubernetes Resources Generated (Total)

| From Sub-chart | Resources                              |
|----------------|----------------------------------------|
| frontend       | ConfigMap, Deployment, Service         |
| backend        | ConfigMap, Deployment, Service         |
| postgres       | Secret, PVC, Deployment, Service       |
| **umbrella**   | **Ingress** (only defined here)        |
| **Total**      | **11 Kubernetes resources**            |

---

## values.yaml — The Master Config

Values here **override** settings from each sub-chart's own `values.yaml`.
The key name must **exactly match** the dependency name in `Chart.yaml`.

```
frontend:           → overrides charts/frontend/values.yaml
  enabled: true
  image:
    repository: tochratana/prod-ui
    tag: "70e14a03"         ← CI/CD updates this on every push to main

backend:            → overrides charts/backend/values.yaml
  enabled: true
  image:
    repository: tochratana/prod-api
    tag: "84112e4b"         ← CI/CD updates this on every push to main
  config:
    SPRING_PROFILES_ACTIVE: "k8s"
  database:
    name: blog_db

postgres:           → overrides charts/postgres/values.yaml
  enabled: true
```

---

## Ingress — Traffic Routing Rules

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"    # auto SSL from Let's Encrypt
    nginx.ingress.kubernetes.io/ssl-redirect: "true"       # force HTTPS
  hosts:
    - host: full-stack-dpl.tochratana.com
      paths:
        - path: /       service: frontend   port: 3000
        - path: /api    service: backend    port: 8080
  tls:
    - secretName: full-stack-dpl-tls
      hosts: [full-stack-dpl.tochratana.com]
```

> The ingress is in the **umbrella chart** (not frontend/backend) because it
> needs to know about both services at the same time to create the routing rules.

---

## Full Traffic Flow

```
Internet
    │  HTTPS (port 443)
    ▼
Ingress: full-stack-dpl.tochratana.com
    │
    ├── /        ──► Service: <release>-frontend:3000
    │                    └── Next.js pod
    │                          └── fetches /api/* (back through ingress)
    │
    └── /api/*   ──► Service: <release>-backend:8080
                         └── Spring Boot pod
                               └── connects to Service: <release>-postgres:5432
                                         └── PostgreSQL pod → PVC → disk
```

---

## CI/CD Integration

GitHub Actions updates `image.tag` in this chart's `values.yaml` after each build:

```yaml
# After CI builds frontend image:
frontend:
  image:
    tag: "new-sha-here"    ← pipeline writes this

# After CI builds backend image:
backend:
  image:
    tag: "new-sha-here"    ← pipeline writes this
```

ArgoCD detects the Git change → triggers Helm upgrade → rolls out new pods automatically.

---

## How to Deploy Manually

```bash
# Update sub-chart dependencies first (creates .tgz files in charts/)
helm dependency update ./charts/full-stack-app

# Dry-run to preview all resources
helm template myapp ./charts/full-stack-app

# Install / upgrade
helm upgrade --install myapp ./charts/full-stack-app -n default
```
