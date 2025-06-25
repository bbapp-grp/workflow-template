# K8s Repository Structure for GitOps

This document shows the expected structure for the `bbapp-grp/k8s` repository that works with our GitOps workflow.

## Repository Structure

```
k8s/
├── base/
│   ├── admin-ui/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   ├── user-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── other-services/...
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── admin-ui-patch.yaml
│   │   └── user-service-patch.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── admin-ui-patch.yaml
│   │   └── user-service-patch.yaml
│   └── prod/
│       ├── kustomization.yaml
│       ├── admin-ui-patch.yaml
│       └── user-service-patch.yaml
└── README.md
```

## Example Files

### Base Deployment (`base/admin-ui/deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
  labels:
    app: admin-ui
spec:
  replicas: 1
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
        image: us-west1-docker.pkg.dev/bbapp-dev-440805/bbapp/admin-ui:latest
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
```

### Base Service (`base/admin-ui/service.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: admin-ui
spec:
  selector:
    app: admin-ui
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: ClusterIP
```

### Base Kustomization (`base/admin-ui/kustomization.yaml`)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: admin-ui
  version: v1
```

### Development Overlay (`overlays/dev/kustomization.yaml`)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: bbapp-dev

resources:
  - ../../base/admin-ui
  - ../../base/user-service

patchesStrategicMerge:
  - admin-ui-patch.yaml
  - user-service-patch.yaml

images:
  - name: admin-ui
    newTag: develop-abc123
  - name: user-service
    newTag: develop-def456

commonLabels:
  environment: dev
```

### Development Patch (`overlays/dev/admin-ui-patch.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: admin-ui
        env:
        - name: NODE_ENV
          value: "development"
        - name: API_URL
          value: "https://api-dev.bbapp.com"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

### Production Overlay (`overlays/prod/kustomization.yaml`)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: bbapp-prod

resources:
  - ../../base/admin-ui
  - ../../base/user-service

patchesStrategicMerge:
  - admin-ui-patch.yaml
  - user-service-patch.yaml

images:
  - name: admin-ui
    newTag: 25.06.1
  - name: user-service
    newTag: 25.06.2

commonLabels:
  environment: prod

replicas:
  - name: admin-ui
    count: 3
  - name: user-service
    count: 5
```

### Production Patch (`overlays/prod/admin-ui-patch.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-ui
spec:
  template:
    spec:
      containers:
      - name: admin-ui
        env:
        - name: NODE_ENV
          value: "production"
        - name: API_URL
          value: "https://api.bbapp.com"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

## How GitOps Updates Work

1. **Development**: Push to `develop` branch → Image built → `overlays/dev/kustomization.yaml` updated directly
2. **Production**: Push to `main` branch → Image built → PR created to update `overlays/prod/kustomization.yaml`
3. **FluxCD**: Watches k8s repository → Detects changes → Applies only changed manifests

## FluxCD Configuration

The k8s repository should have FluxCD configurations:

### `.flux-system/gotk-sync.yaml` (Example)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: bbapp-k8s
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/bbapp-grp/k8s
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: bbapp-dev
  namespace: flux-system
spec:
  interval: 10m
  path: "./overlays/dev"
  prune: true
  sourceRef:
    kind: GitRepository
    name: bbapp-k8s
  targetNamespace: bbapp-dev
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: bbapp-prod
  namespace: flux-system
spec:
  interval: 10m
  path: "./overlays/prod"
  prune: true
  sourceRef:
    kind: GitRepository
    name: bbapp-k8s
  targetNamespace: bbapp-prod
```

## Required GitHub Secrets

Each microservice repository needs this secret:

- `K8S_REPO_TOKEN`: GitHub Personal Access Token with access to the k8s repository

## Testing the GitOps Flow

1. **Test kustomize locally**:
   ```bash
   # In k8s repository
   kustomize build overlays/dev
   kustomize build overlays/prod
   ```

2. **Verify GitOps workflow**:
   - Push to microservice `develop` branch
   - Check if `overlays/dev/kustomization.yaml` gets updated
   - Verify FluxCD deploys the changes

3. **Verify Production flow**:
   - Push to microservice `main` branch
   - Check if PR is created for `overlays/prod/kustomization.yaml`
   - Merge PR and verify FluxCD deploys to production
