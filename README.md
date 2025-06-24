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
- Optional test execution
- Configurable build commands
- Outputs image tags and digest for GitOps integration

### 2. Release Build (`release-build.yml`)

Triggers on pushes to the `main` branch, creates CalVer tags, and builds production-ready images.

**Key Features:**
- Automatic CalVer versioning (YY.MM.PATCH format)
- Creates GitHub releases with deployment information
- Tags images with version numbers
- Git tag creation and push

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

## Usage Examples

### Basic Node.js Microservice

Create `.github/workflows/development.yml`:

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "my-service"
      gcp_project_id: "bbapp-dev-440805"
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

Create `.github/workflows/release.yml`:

```yaml
name: Release Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/release-build.yml@main
    with:
      service_name: "my-service"
      gcp_project_id: "bbapp-dev-440805"
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

### Advanced Configuration

For microservices with custom requirements:

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "my-complex-service"
      gcp_project_id: "bbapp-dev-440805"
      dockerfile_path: "docker/Dockerfile"
      build_context: "."
      node_version: "18"
      enable_tests: true
      test_command: "npm run test:ci"
      build_command: "npm run build"
      artifact_registry_region: "us-west1"
      artifact_registry_repo: "my-custom-repo"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

### Python Microservice

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "python-service"
      gcp_project_id: "bbapp-dev-440805"
      enable_tests: false  # Handle tests in Dockerfile
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

### Go Microservice

```yaml
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "go-service"
      gcp_project_id: "bbapp-dev-440805"
      enable_tests: false  # Go tests handled in Dockerfile
      dockerfile_path: "Dockerfile"
    secrets:
      WIF_PROVIDER: ${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: ${{ secrets.WIF_SERVICE_ACCOUNT }}
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
