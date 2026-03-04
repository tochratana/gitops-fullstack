# 📋 Requirements — gitops-fullstack

Everything you need before deploying this repository.

---

## CLI Tools

| Tool | Minimum Version | Install |
|---|---|---|
| `kubectl` | Matches your cluster | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| `helm` | v3.0+ | [helm.sh/docs](https://helm.sh/docs/intro/install/) |
| `git` | any | [git-scm.com](https://git-scm.com/) |

---

## Kubernetes Cluster

| Requirement | Details |
|---|---|
| **Kubernetes** | v1.24 or newer |
| **Nginx Ingress Controller** | Routes external traffic to frontend/backend services |
| **cert-manager** | v1.0+ — auto-provisions TLS certificates from Let's Encrypt |
| **Default StorageClass** | Required for PostgreSQL persistent storage. Use `local-path` (Rancher) for bare-metal or your cloud provider's default (`gp2`, `standard`, etc.) |

### Verify cluster prerequisites

```bash
# Check Kubernetes version
kubectl version --short

# Check Ingress Controller is running
kubectl get pods -n ingress-nginx

# Check cert-manager is running
kubectl get pods -n cert-manager

# Check a default StorageClass exists
kubectl get storageclass
# Look for "(default)" next to one of the entries
```

---

## GitOps (ArgoCD)

| Requirement | Details |
|---|---|
| **ArgoCD** | v2.0+ installed on the cluster |
| **ArgoCD repo access** | ArgoCD must be able to pull from your Git repository (public or with credentials configured) |

```bash
# Verify ArgoCD is running
kubectl get pods -n argocd
```

---

## Container Registry

| Requirement | Details |
|---|---|
| **Registry access** | Cluster must be able to pull images from your registry (DockerHub, GHCR, ECR, etc.) |
| **Image names** | Default: `tochratana/prod-ui` (frontend), `tochratana/prod-api` (backend), `postgres:17-alpine` (DB) |

If using a **private** registry, create an image pull secret:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<password> \
  -n fullstack
```

Then add to your values:

```yaml
imagePullSecrets:
  - name: regcred
```

---

## DNS

| Requirement | Details |
|---|---|
| **Domain** | Must point to the Ingress Controller's external IP/LoadBalancer |
| **Default domain** | `full-stack-dpl.tochratana.com` (change in ingress values) |

```bash
# Find your Ingress external IP
kubectl get svc -n ingress-nginx

# Create a DNS A record:
# your-domain.com → <EXTERNAL-IP>
```

---

## Quick Checklist

```
[ ] kubectl installed and configured
[ ] helm v3+ installed
[ ] Kubernetes cluster v1.24+ accessible
[ ] Nginx Ingress Controller deployed
[ ] cert-manager deployed
[ ] Default StorageClass configured
[ ] ArgoCD installed
[ ] Container images pushed to registry
[ ] DNS pointing to Ingress external IP
[ ] postgres-secret created in target namespace
```
