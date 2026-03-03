# Fullstack Application GitOps Repository

## Overview

This repository contains the GitOps configuration for deploying a fullstack application with:
* Frontend: Next.js/TypeScript application
* Backend: Spring Boot Java application
* Database: PostgreSQL
* Ingress: Domain-based routing with SSL/TLS

The project uses a library chart pattern to maximize code reuse and maintain consistency across all services while following GitOps principles for deployment automation.


```bash
User Request
    ↓
  Ingress (Domain: full-stack-dpl.tochratana.com)
    ↓
┌─────────────────────────────────────┐
│         /api → Backend Service       │
│         /    → Frontend Service      │
└─────────────────────────────────────┘
    ↓               ↓
Frontend Pod    Backend Pod
    ↓               ↓
              PostgreSQL Pod
                   ↓
              Persistent Volume
```


## Repository Structure

```bash
gitops-repo/
├── charts/
│   ├── library/                 # Shared templates library
│   │   ├── Chart.yaml
│   │   └── templates/
│   │       ├── _deployment.yaml
│   │       ├── _service.yaml
│   │       ├── _configmap.yaml
│   │       ├── _pvc.yaml
│   │       ├── _secret.yaml
│   │       └── _helpers.tpl
│   ├── frontend/                 # Next.js frontend chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── frontend.yaml
│   ├── backend/                  # Spring Boot backend chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── backend.yaml
│   ├── postgres/                 # PostgreSQL database chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── postgres.yaml
│   └── fullstack-app/            # Main umbrella chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           └── ingress.yaml
├── environments/
│   ├── dev/                      # Development configuration
│   │   └── values.yaml
│   └── prod/                     # Production configuration
│       └── values.yaml
├── .github/
│   └── workflows/
│       └── deploy.yaml           # CI/CD pipeline
├── update-deps.sh                 # Dependency update script
└── README.md
```
Prerequisites

* Kubernetes cluster
* Helm
* Kubectl
* Ingress Controller (nginx-ingress recommended)
* cert-manager (for SSL certificates)
* GitHub Actions (for CI/CD) or ArgoCD (for GitOps)

## Quick Start