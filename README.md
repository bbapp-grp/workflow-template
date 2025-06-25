# BBApp Workflow Templates

This repository contains reusable GitHub Actions workflow templates for the BBApp microservices ecosystem. These templates provide standardized CI/CD pipelines that can be used across all microservices to ensure consistency and reduce code duplication.

## Overview

The templates support:
- **Development builds**: Automated builds on `develop` branch with `latest` and commit-based tags
- **Release builds**: Automated builds on `main` branch with CalVer versioning and GitHub releases
- **Google Artifact Registry**: Secure image storage using Workload Identity Federation
- **Multi-language support**: Configurable for Node.js, Python, Go, and other languages
- **Flexible testing**: Optional test execution with configurable commands
- **GitOps integration**: Outputs that can be used to update Kubernetes manifests

## Workflows

### 1. Development Build (`development-build.yml`)

Triggers on pushes to the `develop` branch and builds images with `latest` and commit-based tags.

**Key Features:**
- Tags images with `latest` and `develop-<sha>`
- Configurable build commands
- Outputs image tags and digest for GitOps integration

### 2. Release Build (`release-build.yml`)

Triggers on pushes to the `main` branch, creates CalVer tags, and builds production-ready images.

**Key Features:**
- Automatic CalVer versioning (YY.MM.PATCH format)
- Creates GitHub releases with deployment information
- Tags images with version numbers
- Git tag creation and push

### 3. GitOps Manifest Update (`gitops-update.yml`)

Updates Kubernetes manifests in a separate repository after successful image builds.

**Key Features:**
- Updates kustomize image tags automatically
- Supports both direct commits and PR creation
- Validates kustomization before committing
- Configurable for different environments (dev/staging/prod)
- Detailed commit messages with traceability

### 4. Test Templates

Language-specific reusable test workflows that can be used as separate jobs before building:

#### Node.js Test Template (`nodejs-test.yml`)
```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/nodejs-test.yml@main
  with:
    node_version: '20'
    test_command: 'npm test'
    lint_command: 'npm run lint'
    type_check_command: 'npm run type-check'
    enable_lint: true
    enable_type_check: true
```

#### Go Test Template (`golang-test.yml`)
```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/golang-test.yml@main
  with:
    go_version: '1.21'
    test_command: 'go test ./...'
    lint_command: 'golangci-lint run'
    enable_race_detection: true
```

#### Python Test Template (`python-test.yml`)
```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/python-test.yml@main
  with:
    python_version: '3.11'
    test_command: 'pytest'
    lint_command: 'flake8 .'
    format_check_command: 'black --check .'
    type_check_command: 'mypy .'
```

## Prerequisites

### 1. Workload Identity Federation Setup

Each microservice repository needs the following secrets configured:

- `WIF_PROVIDER`: Your Workload Identity Federation provider
- `WIF_SERVICE_ACCOUNT`: Your service account email

### 2. Google Artifact Registry

Ensure you have:
- A GCP project with Artifact Registry enabled
- A Docker repository created in Artifact Registry
- Proper IAM permissions for the service account

### 3. Repository Structure

Your microservice repository should have:
- A `Dockerfile` in the root (or specify custom path)
- A `package.json` if using Node.js features
- Proper test scripts if enabling test execution

### 4. GitOps Integration (Optional)

For automatic Kubernetes manifest updates:

- **K8s Repository**: A separate repository (e.g., `bbapp-grp/k8s`) with kustomize manifests
- **Kustomize Structure**: Base manifests and environment overlays
- **GitHub Token**: Personal Access Token with access to the k8s repository
- **FluxCD**: Configured to watch the k8s repository

See [`examples/k8s-repo-structure.md`](examples/k8s-repo-structure.md) for detailed setup instructions.

## Usage Examples

### Node.js Microservice (Recommended)

Create `.github/workflows/development.yml`:

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  test:
    name: Run Tests
    uses: bbapp-grp/workflow-template/.github/workflows/nodejs-test.yml@main
    with:
      node_version: '20'
      test_command: 'npm test'
      lint_command: 'npm run lint'
      type_check_command: 'npm run type-check'
      enable_lint: true
      enable_type_check: true

  build:
    name: Build and Push
    needs: test
    if: success()
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

Create `.github/workflows/release.yml`:

```yaml
name: Release Build

on:
  push:
    branches: [ main ]

jobs:
  test:
    name: Run Tests
    uses: bbapp-grp/workflow-template/.github/workflows/nodejs-test.yml@main
    with:
      node_version: '20'
      test_command: 'npm test'
      lint_command: 'npm run lint'
      type_check_command: 'npm run type-check'
      enable_lint: true
      enable_type_check: true

  build:
    name: Build and Push
    needs: test
    if: success()
    uses: bbapp-grp/workflow-template/.github/workflows/release-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

### Go Microservice

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  test:
    uses: bbapp-grp/workflow-template/.github/workflows/golang-test.yml@main
    with:
      go_version: '1.21'
      test_command: 'go test ./...'
      lint_command: 'golangci-lint run'
      enable_race_detection: true

  build:
    needs: test
    if: success()
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

### Python Microservice

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  test:
    uses: bbapp-grp/workflow-template/.github/workflows/python-test.yml@main
    with:
      python_version: '3.11'
      test_command: 'pytest'
      lint_command: 'flake8 .'
      format_check_command: 'black --check .'
      type_check_command: 'mypy .'

  build:
    needs: test
    if: success()
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

### Basic Microservice (Docker-only testing)

For services that prefer to handle all testing in the Dockerfile:

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

## GitOps Integration

The workflows output image information that can be used by GitOps processes:

```yaml
jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "my-service"
      gcp_project_id: "bbapp-dev-440805"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
  
  update-manifests:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Update Kubernetes manifests
        run: |
          echo "New image: ${{ needs.build.outputs.image_tag }}"
          echo "Image digest: ${{ needs.build.outputs.image_digest }}"
          # Add logic to update your K8s manifests repository
```

## Input Parameters

### Common Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `service_name` | Name of the microservice | Yes | - |
| `gcp_project_id` | GCP Project ID | Yes | - |
| `dockerfile_path` | Path to Dockerfile | No | `Dockerfile` |
| `build_context` | Docker build context | No | `.` |
| `artifact_registry_region` | AR region | No | `us-central1` |
| `artifact_registry_repo` | AR repository name | No | `bbapp-microservices` |
| `node_version` | Node.js version | No | `20` |
| `enable_tests` | Run tests before build | No | `true` |
| `test_command` | Test command to run | No | `npm test` |
| `build_command` | Build command | No | `''` |

### Release-specific Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `tag_prefix` | Version tag prefix | No | `v` |

## Outputs

### Development Build

- `image_tag`: Full image tag that was built
- `image_digest`: SHA256 digest of the image

### Release Build

- `image_tag`: Full image tag that was built
- `image_digest`: SHA256 digest of the image
- `version_tag`: The version tag that was created

## Migration Guide

### From Existing Workflows

1. **Backup existing workflows**:
   ```bash
   cp .github/workflows/development.yml .github/workflows/development.yml.backup
   cp .github/workflows/release.yml .github/workflows/release.yml.backup
   ```

2. **Replace workflow content** with examples above

3. **Update service name** to match your microservice

4. **Test with a small change** on develop branch

5. **Verify image is pushed** to Artifact Registry

6. **Test release process** with a merge to main

### Validation Checklist

- [ ] Development builds work on develop branch
- [ ] Release builds work on main branch
- [ ] Images are pushed to correct Artifact Registry location
- [ ] CalVer versioning works correctly
- [ ] GitHub releases are created
- [ ] Git tags are created and pushed
- [ ] Tests run successfully (if enabled)
- [ ] Output values are correct for GitOps integration

## Troubleshooting

### Common Issues

1. **Authentication failures**:
   - Verify WIF_PROVIDER and WIF_SERVICE_ACCOUNT secrets
   - Check service account permissions
   - Ensure repository is in the bbapp-grp organization

2. **Image push failures**:
   - Verify Artifact Registry repository exists
   - Check service account has Artifact Registry Writer role
   - Ensure correct project ID and repository name

3. **Test failures**:
   - Set `enable_tests: false` to skip tests temporarily
   - Verify `test_command` is correct for your project
   - Check that dependencies are installed correctly

4. **CalVer tag conflicts**:
   - Check for existing tags with same version
   - Ensure git configuration is correct
   - Verify push permissions to repository

### Getting Help

1. Check workflow run logs in GitHub Actions
2. Verify all required secrets are set
3. Test WIF authentication manually if needed
4. Review Artifact Registry permissions

## Contributing

To contribute to these workflow templates:

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test with a sample microservice
5. Submit a pull request

### Testing Changes

Before submitting changes:

1. Test both development and release workflows
2. Verify outputs are correct
3. Check error handling scenarios
4. Update documentation as needed

## License

This project is licensed under the MIT License - see the LICENSE file for details.
