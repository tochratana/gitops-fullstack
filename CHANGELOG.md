# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> **How to add a new release:** Copy the `[Unreleased]` section, rename it to `[vX.Y.Z] - YYYY-MM-DD`, and create a fresh `[Unreleased]` section above it.

---

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
