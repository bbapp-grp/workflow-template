# GitOps Integration Guide

This document explains how to integrate the BBApp workflow templates with GitOps using FluxCD for automated deployments.

## Overview

The workflow templates are designed to work seamlessly with GitOps by:

1. **Building and tagging images** with consistent naming conventions
2. **Outputting image metadata** for use by GitOps tools
3. **Supporting per-service deployments** through targeted image updates
4. **Enabling automated manifest updates** through workflow outputs

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Microservice  │    │    Workflow     │    │   GitOps Repo   │
│   Repository    │───▶│   Templates     │───▶│   (K8s Manifests)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       ▼
         │              ┌─────────────────┐    ┌─────────────────┐
         │              │ Artifact Registry│    │    FluxCD       │
         │              │   (Images)      │    │  (Deployment)   │
         │              └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       └───────────────────────┼─────▶ GKE Cluster
         └─────────────────────────────────────────────────────▶ (Running Pods)
```

## GitOps Repository Structure

```
k8s-manifests/
├── environments/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   └── services/
│   │       ├── admin-ui/
│   │       │   ├── deployment.yaml
│   │       │   ├── service.yaml
│   │       │   └── kustomization.yaml
│   │       ├── auth-service/
│   │       └── user-service/
│   └── production/
│       ├── kustomization.yaml
│       └── services/
│           ├── admin-ui/
│           ├── auth-service/
│           └── user-service/
├── base/
│   ├── admin-ui/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── kustomization.yaml
│   ├── auth-service/
│   └── user-service/
└── flux-system/
    ├── gotk-components.yaml
    ├── gotk-sync.yaml
    ├── image-automation/
    │   ├── image-repositories.yaml
    │   ├── image-policies.yaml
    │   └── image-updates.yaml
    └── kustomizations/
        ├── development.yaml
        └── production.yaml
```

## Image Naming Convention

The workflow templates use consistent image naming:

### Development Environment
- **Registry**: `us-central1-docker.pkg.dev`
- **Repository**: `bbapp-dev-440805/bbapp-microservices`
- **Tags**: 
  - `latest` (always points to latest develop build)
  - `develop-<commit-sha>` (specific commit reference)

**Example**: `us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui:latest`

### Production Environment
- **Registry**: `us-central1-docker.pkg.dev`
- **Repository**: `bbapp-dev-440805/bbapp-microservices`
- **Tags**:
  - `latest` (latest release)
  - `24.06.1` (CalVer version)
  - `v24.06.1` (full version tag)

**Example**: `us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui:24.06.1`

## FluxCD Configuration

### 1. Image Repository Setup

Create `flux-system/image-automation/image-repositories.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: admin-ui
  namespace: flux-system
spec:
  image: us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui
  interval: 1m
  provider: gcp
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: auth-service
  namespace: flux-system
spec:
  image: us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/auth-service
  interval: 1m
  provider: gcp
---
# Add more services as needed
```

### 2. Image Policy Setup

Create `flux-system/image-automation/image-policies.yaml`:

```yaml
# Development policies (track latest)
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: admin-ui-dev
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: admin-ui
  policy:
    semver:
      range: 'latest'
---
# Production policies (track semantic versions)
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: admin-ui-prod
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: admin-ui
  policy:
    semver:
      range: '>=24.0.0'
---
# Add policies for other services
```

### 3. Image Update Automation

Create `flux-system/image-automation/image-updates.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: development-image-updates
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: k8s-manifests
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: |
        [ci skip] Update development images
        
        Updated images:
        {{range .Updated.Images}}
        - {{.}}
        {{end}}
    push:
      branch: main
  update:
    path: "./environments/development"
    strategy: Setters
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: production-image-updates
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: k8s-manifests
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: |
        [ci skip] Update production images
        
        Updated images:
        {{range .Updated.Images}}
        - {{.}}
        {{end}}
    push:
      branch: main
  update:
    path: "./environments/production"
    strategy: Setters
```

## Kubernetes Manifests with Image Automation

### Base Deployment

Create `base/admin-ui/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
  labels:
    app: admin-ui
spec:
  replicas: 2
  selector:
    matchLabels:
      app: admin-ui
  template:
    metadata:
      labels:
        app: admin-ui
    spec:
      containers:
      - name: admin-ui
        image: us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui:latest # {"$imagepolicy": "flux-system:admin-ui-dev"}
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Environment-specific Overlays

Create `environments/development/services/admin-ui/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: development

resources:
- ../../../../base/admin-ui

patches:
- target:
    kind: Deployment
    name: admin-ui
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui:latest # {"$imagepolicy": "flux-system:admin-ui-dev"}
    - op: replace
      path: /spec/template/spec/containers/0/env/0/value
      value: "development"
```

Create `environments/production/services/admin-ui/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
- ../../../../base/admin-ui

patches:
- target:
    kind: Deployment
    name: admin-ui
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: us-central1-docker.pkg.dev/bbapp-dev-440805/bbapp-microservices/admin-ui:24.06.1 # {"$imagepolicy": "flux-system:admin-ui-prod"}
    - op: replace
      path: /spec/replicas
      value: 3
```

## Workflow Integration

### Enhanced Workflow with GitOps Updates

You can extend the workflow templates to automatically update GitOps manifests:

```yaml
name: Development Build with GitOps

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "admin-ui"
      gcp_project_id: "bbapp-dev-440805"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
  
  update-gitops:
    needs: build
    runs-on: ubuntu-latest
    if: success()
    steps:
      - name: Update GitOps Repository
        uses: actions/checkout@v4
        with:
          repository: bbapp-grp/k8s-manifests
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops
      
      - name: Update development image
        run: |
          cd gitops
          # Extract image tag from build output
          NEW_IMAGE="${{ needs.build.outputs.image_tag }}"
          
          # Update the development overlay
          sed -i 's|admin-ui:.*|admin-ui:'$(echo $NEW_IMAGE | cut -d: -f2)'|g' \
            environments/development/services/admin-ui/kustomization.yaml
          
          # Commit and push changes
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "Update admin-ui development image to $(echo $NEW_IMAGE | cut -d: -f2)" || exit 0
          git push
```

## Deployment Flow

### Development Environment

1. **Developer pushes** to `develop` branch
2. **Workflow builds** and pushes image with `latest` tag
3. **FluxCD detects** new image (1-minute interval)
4. **FluxCD updates** development manifests automatically
5. **FluxCD deploys** to development namespace
6. **Only the changed service** is redeployed

### Production Environment

1. **Developer merges** to `main` branch
2. **Workflow builds** and pushes image with CalVer tag
3. **FluxCD detects** new semantic version (5-minute interval)
4. **FluxCD updates** production manifests automatically
5. **FluxCD deploys** to production namespace with rolling update
6. **Only the changed service** is redeployed

## Monitoring and Observability

### FluxCD Monitoring

Monitor GitOps operations:

```bash
# Check image repositories
kubectl get imagerepositories -n flux-system

# Check image policies
kubectl get imagepolicies -n flux-system

# Check image update automations
kubectl get imageupdateautomations -n flux-system

# Check for FluxCD events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Deployment Monitoring

Monitor deployments:

```bash
# Check deployment status
kubectl get deployments -n development
kubectl get deployments -n production

# Check pod status
kubectl get pods -n development -l app=admin-ui
kubectl get pods -n production -l app=admin-ui

# Check deployment history
kubectl rollout history deployment/admin-ui -n development
```

## Security Considerations

### 1. Image Scanning

Integrate image scanning into workflows:

```yaml
- name: Scan image for vulnerabilities
  uses: anchore/scan-action@v3
  with:
    image: ${{ needs.build.outputs.image_tag }}
    fail-build: true
    severity-cutoff: critical
```

### 2. Policy Enforcement

Use OPA Gatekeeper for policy enforcement:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: allowedregistries
spec:
  crd:
    spec:
      names:
        kind: AllowedRegistries
      validation:
        properties:
          registries:
            type: array
            items:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package allowedregistries
        
        violation[{"msg": msg}] {
          input.review.object.spec.template.spec.containers[_].image
          not starts_with(input.review.object.spec.template.spec.containers[_].image, input.parameters.registries[_])
          msg := "Container image must come from allowed registries"
        }
```

### 3. RBAC Configuration

Configure appropriate RBAC for FluxCD:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: image-automation-controller
  namespace: flux-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: image-automation-controller
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "patch"]
```

## Troubleshooting

### Common Issues

1. **Image not updating**:
   - Check ImageRepository status
   - Verify image policy configuration
   - Check FluxCD controller logs

2. **Failed deployments**:
   - Check deployment logs
   - Verify resource limits
   - Check health check endpoints

3. **GitOps repository not updating**:
   - Verify FluxCD has write access
   - Check ImageUpdateAutomation configuration
   - Review git credentials

### Debug Commands

```bash
# Check FluxCD status
flux get all

# Check specific resource
flux get imagerepository admin-ui
flux get imagepolicy admin-ui-dev

# Check logs
kubectl logs -n flux-system deployment/image-automation-controller
kubectl logs -n flux-system deployment/image-reflector-controller

# Force reconciliation
flux reconcile imagerepository admin-ui
flux reconcile imagepolicy admin-ui-dev
```

This GitOps integration ensures that your multi-microservice environment can automatically deploy only the services that have changed, providing efficient and reliable continuous deployment.
