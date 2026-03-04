# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> **How to add a new release:** Copy the `[Unreleased]` section, rename it to `[vX.Y.Z] - YYYY-MM-DD`, and create a fresh `[Unreleased]` section above it.

---

## 1.0.0 (2026-03-04)


### Bug Fixes

* add -d blog_db to postgres readiness/liveness probes ([a7c86ae](https://github.com/tochratana/gitops-fullstack/commit/a7c86aec4395d24ff29cf0e2891b36ac77133e0b))
* assign permission for gradle ([37e1174](https://github.com/tochratana/gitops-fullstack/commit/37e117484f0c0f6d9d8b01ef2b8c19e4ea410da5))
* assign permission for gradle ([7564737](https://github.com/tochratana/gitops-fullstack/commit/7564737b370b06cea48357960dc294f57d4176b7))
* assign permission for gradle ([296821a](https://github.com/tochratana/gitops-fullstack/commit/296821ab4d71584325878c83833fff17fcfb7dd3))
* backend CrashLoopBackOff - add startupProbe, fix probe timings, fix frontend image name ([23a5219](https://github.com/tochratana/gitops-fullstack/commit/23a52194125aa05116ad2ac070cec354bfdbc532))
* bundle library dependency in sub-charts and fix commonLabels optional arg ([600c147](https://github.com/tochratana/gitops-fullstack/commit/600c147eb817736478aedf35b2b56a9be28ba0f3))
* bundle library dependency in sub-charts and fix commonLabels optional arg ([a940185](https://github.com/tochratana/gitops-fullstack/commit/a940185f133b3758083ec25be24a8601957d9dc5))
* bundle library dependency in sub-charts and fix commonLabels optional arg ([9be8552](https://github.com/tochratana/gitops-fullstack/commit/9be8552ef89f2c2965348e390d3eb1f168cd6a5a))
* bundle library dependency in sub-charts and fix commonLabels optional arg ([d20851b](https://github.com/tochratana/gitops-fullstack/commit/d20851b45faedbc1d711b7d63ec26beab9b8d4e9))
* correct prod image tags and remove invalid Helm expressions in values.yaml ([6d4408c](https://github.com/tochratana/gitops-fullstack/commit/6d4408c7df9c45c32f8c3c105969795040490e17))
* new structure ([ca53a08](https://github.com/tochratana/gitops-fullstack/commit/ca53a08359f5b6759452b57b71b9535f4b37fae5))
* rebuild sub-chart tarballs in full-stack-app with updated templates ([c3e9233](https://github.com/tochratana/gitops-fullstack/commit/c3e92339dfc9f9fc4581d34bca229e24ade6ced3))
* rename database from appdb to blog_db ([84148d6](https://github.com/tochratana/gitops-fullstack/commit/84148d6db57aa292d2181cc088eb1ba095cb9f0d))
* rename database from appdb to blog_db to match Spring Boot application ([8e5bef7](https://github.com/tochratana/gitops-fullstack/commit/8e5bef7b62f1c1cb664121cfa654b1d84d2c5983))
* set fixed postgres password to prevent auth failures on re-sync ([8ae074a](https://github.com/tochratana/gitops-fullstack/commit/8ae074a4780432aa812bfce6bb00e595ee7ea713))
* testing ([3ccfc6d](https://github.com/tochratana/gitops-fullstack/commit/3ccfc6d3d4b5e29635b7bd90f6eb1fd79d879019))
* testing ([cc91265](https://github.com/tochratana/gitops-fullstack/commit/cc91265ea36464410132576ea7f043addbc8649d))
* testing ([174bdaf](https://github.com/tochratana/gitops-fullstack/commit/174bdafae219ce310b83c97c0abb9ffb4f740b1c))
* use correct sub-chart key structure for image overrides (images.x -&gt; x.image) ([46eff6c](https://github.com/tochratana/gitops-fullstack/commit/46eff6c5d8c62b9b3b31a896a39c124202970007))

## [Unreleased]

_Nothing yet._

---

## [v1.0.0] - 2026-03-04

### Added

- **Umbrella Helm chart** (`full-stack-app`) — deploys frontend, backend, and postgres as a single ArgoCD application
- **Frontend sub-chart** — Next.js app (port 3000) with configurable `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_APP_NAME`
- **Backend sub-chart** — Spring Boot API (port 8080) with auto-injected datasource env vars from postgres secret
- **PostgreSQL sub-chart** — PostgreSQL 17-alpine with persistent volume, auto-generated secret, and health probes
- **Library chart** — shared Helm templates for Deployment, Service, ConfigMap, Secret, and PVC
- **Ingress** — nginx-based ingress with TLS (cert-manager / Let's Encrypt), routes `/` → frontend, `/api` → backend
- **Environment overlays** — `environments/dev/` and `environments/prod/` value files for per-environment config
- **Auto push script** (`push.sh`) — one-command workflow: helm dep update → git add → commit → push
- **Flexible deployment** — enable/disable frontend, backend, or postgres independently via `<component>.enabled`
- **Backend startup/liveness/readiness probes** — Spring Actuator health endpoints
- **PostgreSQL probes** — `pg_isready` liveness and readiness checks
- **Comprehensive README** — deployment guides for fullstack, frontend-only, backend-only, postgres-only, and fork/adapt instructions
- **REQUIREMENTS.md** — infrastructure prerequisites checklist
