# Fullstack Application GitOps Repository

This repository contains the GitOps configuration for deploying a fullstack application with:
- Next.js/TypeScript Frontend
- Spring Boot Backend
- PostgreSQL Database
- Ingress with domain name

## Prerequisites

- Kubernetes cluster
- Helm v3+
- kubectl
- Ingress Controller (nginx-ingress)
- cert-manager (for SSL certificates)

## Directory Structure

- `/charts/fullstack-app` - Helm chart for the application
- `/environments` - Environment-specific configurations
  - `/dev` - Development environment
  - `/prod` - Production environment

## Deployment

### Manual Deployment

```bash
# Deploy to dev
helm upgrade --install fullstack-app-dev ./charts/fullstack-app \
  --namespace fullstack-dev \
  --create-namespace \
  --values ./environments/dev/values.yaml

# Deploy to prod
helm upgrade --install fullstack-app-prod ./charts/fullstack-app \
  --namespace fullstack-prod \
  --create-namespace \
  --values ./environments/prod/values.yaml