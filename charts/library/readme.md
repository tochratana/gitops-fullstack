# 📚 Library Chart Notes

## What This Chart Does
A **library chart** — contains only reusable Helm template helpers.
It generates **NO Kubernetes resources on its own**.
Every other chart (frontend, backend, postgres) depends on it to avoid copy-paste.

---

## Chart Structure

```
charts/library/
├── Chart.yaml        # type: library (not application!)
└── templates/
    ├── _helpers.tpl      # Common label helpers
    ├── _configmap.yaml   # library.configmap template
    ├── _deployment.yaml  # library.deployment template
    ├── _service.yaml     # library.service template
    ├── _secret.yaml      # library.secret template
    └── _pvc.yaml         # library.pvc template
```

> 💡 **All files start with `_`** — this tells Helm they are **partial templates**,
> not standalone manifests. Helm will never render them directly as resources.

---

## chart type: library

```yaml
# Chart.yaml
type: library    ← key difference!
```

| `type: application` | `type: library` |
|---|---|
| Generates K8s resources | Generates NO resources |
| Can be deployed alone | Cannot be deployed alone |
| frontend / backend / postgres | library chart |

---

## Available Templates

### 1. `library.commonLabels` — _helpers.tpl
Generates standard Kubernetes labels applied to every resource:
```yaml
app.kubernetes.io/name: <chart-name>
app.kubernetes.io/instance: <release-name>
app.kubernetes.io/component: <component>   # e.g. "frontend", "backend"
app.kubernetes.io/managed-by: Helm
helm.sh/chart: library-0.1.0
```

---

### 2. `library.configmap` — _configmap.yaml
Creates a ConfigMap from a `config` dict.
```
Input:  ($ root, $component name, dict with config key)
Output: ConfigMap named <release>-<component>-config
```
```yaml
# Example output:
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-backend-config
data:
  SPRING_PROFILES_ACTIVE: k8s
  SERVER_PORT: "8080"
```

---

### 3. `library.deployment` — _deployment.yaml
Creates a full Deployment with support for:
- `image`, `imagePullPolicy`, `imagePullSecrets`
- `ports` (container ports)
- `env` (plain env vars)
- `envFrom` (ConfigMap / Secret refs)
- `resources` (requests & limits)
- `probes` (startup, liveness, readiness)
- `volumeMounts` + `volumes`
```
Input:  ($ root, $component name, $values dict)
Output: Deployment named <release>-<component>
```

---

### 4. `library.service` — _service.yaml
Creates a Service (ClusterIP or other type).
```
Input:  ($ root, $component name, $values dict)
Output: Service named <release>-<component>
```
Iterates over `service.ports` to define all port mappings.

---

### 5. `library.secret` — _secret.yaml
Creates a Kubernetes Secret with base64-encoded values.
```
Input:  ($ root, $component name, dict with secretType + secretData)
Output: Secret named <release>-<component>-secret
```
```yaml
# Example output:
apiVersion: v1
kind: Secret
type: Opaque
data:
  username: YXBwdXNlcg==     # base64("appuser")
  password: U3Ryb25n...      # base64("StrongP@ssw0rd2026")
```

---

### 6. `library.pvc` — _pvc.yaml
Creates a PersistentVolumeClaim for disk storage.
```
Input:  ($ root, $component name, $values dict)
Output: PVC named <release>-<component>-pvc
```
Uses `persistence.size`, `persistence.accessModes`, `persistence.storageClass` from values.

---

## How Templates Are Called

Each chart calls library templates using `include`:

```yaml
# Syntax:
{{- include "library.<templateName>" (list $ $component $values) }}

# Real examples from backend.yaml:
{{- include "library.configmap"  (list $ $component (dict "config" $values.config)) }}
{{- include "library.deployment" (list $ $component $backendValues) }}
{{- include "library.service"    (list $ $component $values) }}
```

Arguments are always passed as a **list** `(list arg1 arg2 arg3)` because Helm
templates only accept a single argument — so a list is used to bundle multiple values.

---

## Why a Library Chart? (vs copy-paste)

Without the library chart, every service chart would need its own:
- `deployment.yaml` (identical structure, just different names)
- `service.yaml` (identical structure)
- `configmap.yaml` (identical structure)

**With the library**: fix a bug or add a feature (e.g. add `topologySpreadConstraints`)
in ONE place → all charts (frontend, backend, postgres) get the update automatically.

---

## Template Usage by Chart

| Template            | frontend | backend | postgres |
|---------------------|----------|---------|----------|
| `library.configmap` | ✅       | ✅      | ❌       |
| `library.deployment`| ✅       | ✅      | ✅       |
| `library.service`   | ✅       | ✅      | ✅       |
| `library.secret`    | ❌       | ❌      | ✅       |
| `library.pvc`       | ❌       | ❌      | ✅       |
| `library.commonLabels`| ✅     | ✅      | ✅       |
