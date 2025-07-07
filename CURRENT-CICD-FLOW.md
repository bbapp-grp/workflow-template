# Current CI/CD Flow (Direct Deployment)

This document describes the current CI/CD approach used for BBApp microservices using direct GitHub Actions deployment.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Microservice  │    │  Workflow Template │    │   GKE Cluster   │
│   Repository    │────▶│   Repository      │────▶│                 │
│                 │    │                   │    │                 │
│  • Source Code  │    │  • Build Templates│    │  • Development  │
│  • Dockerfile   │    │  • Test Templates │    │  • Staging      │
│  • Workflows    │    │  • Deploy Logic   │    │  • Production   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Workflow Structure

Each microservice has exactly **3 workflows**:

### 1. `test.yml` - Runs on Pull Requests
```yaml
name: Tests
on:
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    uses: bbapp-grp/workflow-template/.github/workflows/rust-test.yml@main
    # or golang-test.yml, nodejs-test.yml, python-test.yml
```

### 2. `development.yml` - Runs on Push to `develop`
```yaml
name: Development Build
on:
  push:
    branches: [ develop ]

jobs:
  build-app:
    uses: bbapp-grp/workflow-template/.github/workflows/rust-development-build.yml@main
    
  deploy-dev:
    needs: build-app
    # Direct kubectl deployment to development namespace
```

### 3. `release.yml` - Runs on Push to `main`
```yaml
name: Release Build
on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/rust-release-build.yml@main
    
  deploy-stg:
    needs: build
    # Direct kubectl deployment to staging namespace
```

## Deployment Flow

### Development Environment
1. **Trigger**: Push to `develop` branch
2. **Build**: Creates image with tag `develop-{sha}`
3. **Deploy**: Direct `kubectl set image` to development namespace
4. **Verify**: `kubectl rollout status` confirms deployment

### Staging Environment
1. **Trigger**: Push to `main` branch
2. **Build**: Creates image with tag `v{short-sha}`
3. **Deploy**: Direct `kubectl set image` to staging namespace
4. **Verify**: `kubectl rollout status` confirms deployment

## Key Benefits

✅ **Fast Deployment**: No GitOps reconciliation delay  
✅ **Simple**: Direct deployment, no intermediate repositories  
✅ **Reliable**: Immediate feedback on deployment status  
✅ **Consistent**: Same pattern across all microservices  

## Example Implementation

See existing services for reference:
- `order-service` (Go)
- `product-service` (Go)
- `notification-service` (Rust)
- `customer-service` (Python)

## Migration from GitOps

If migrating from the old GitOps approach:

1. Remove any `gitops-update` job references
2. Add direct deployment jobs using `kubectl set image`
3. Remove GitOps-related secrets (`K8S_REPO_TOKEN`, etc.)
4. Test the direct deployment flow

## No GitOps Components Required

❌ **Not Used**: FluxCD, ArgoCD, or any GitOps operators  
❌ **Not Used**: Separate K8s manifest repositories  
❌ **Not Used**: Kustomize auto-updates  
❌ **Not Used**: GitOps reconciliation loops  

The deployment is **direct** and **immediate** via GitHub Actions.
