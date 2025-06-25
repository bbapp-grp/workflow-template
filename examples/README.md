# Example Workflow Files

This directory contains example workflow files that microservices can copy and customize for their specific needs.

## Available Examples

### Basic Examples (Docker-only)
- `development.yml` - Simple Docker build and push for development
- `release.yml` - Simple Docker build and push for releases

### Language-Specific Examples with Testing
- `nodejs-development.yml` - Node.js development workflow with testing
- `nodejs-release.yml` - Node.js release workflow with testing
- `golang-development.yml` - Go development workflow with testing
- `python-development.yml` - Python development workflow with testing

### Advanced Examples
- `advanced-development.yml` - Development workflow with custom Docker configuration
- `advanced-release.yml` - Release workflow with custom Docker configuration

## Testing Approaches

We provide two approaches for testing in your CI/CD pipelines:

### Approach 1: Language-Specific Test Templates (Recommended)
Use our reusable test templates that are optimized for specific languages. This provides faster feedback, better error reporting, and more flexibility.

```yaml
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
```

### Approach 2: Docker-Only Testing (Simpler)
All testing happens inside the Docker build process. The workflow only handles Docker build and push.

```yaml
# Basic workflow - tests run in Dockerfile
jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
```

**Dockerfile example:**
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go test ./...  # Tests run here
RUN go build -o app .

FROM alpine:latest
COPY --from=builder /app/app .
CMD ["./app"]
```

## Available Test Templates

We provide reusable test templates for common languages:

### Node.js Test Template
**File:** `.github/workflows/nodejs-test.yml`

```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/nodejs-test.yml@main
  with:
    node_version: '20'              # Node.js version (default: '20')
    test_command: 'npm test'        # Test command (default: 'npm test')
    lint_command: 'npm run lint'    # Lint command (default: 'npm run lint')
    type_check_command: 'npm run type-check'  # Type check command
    enable_lint: true               # Enable linting (default: true)
    enable_type_check: true         # Enable type checking (default: true)
    working_directory: '.'          # Working directory (default: '.')
```

### Go Test Template
**File:** `.github/workflows/golang-test.yml`

```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/golang-test.yml@main
  with:
    go_version: '1.21'              # Go version (default: '1.21')
    test_command: 'go test ./...'   # Test command (default: 'go test ./...')
    lint_command: 'golangci-lint run'  # Lint command
    vet_command: 'go vet ./...'     # Vet command (default: 'go vet ./...')
    enable_lint: true               # Enable linting (default: true)
    enable_vet: true                # Enable go vet (default: true)
    enable_race_detection: true     # Enable race detection (default: true)
    working_directory: '.'          # Working directory (default: '.')
```

### Python Test Template
**File:** `.github/workflows/python-test.yml`

```yaml
test:
  uses: bbapp-grp/workflow-template/.github/workflows/python-test.yml@main
  with:
    python_version: '3.11'          # Python version (default: '3.11')
    test_command: 'pytest'          # Test command (default: 'pytest')
    lint_command: 'flake8 .'        # Lint command (default: 'flake8 .')
    format_check_command: 'black --check .'  # Format check command
    type_check_command: 'mypy .'    # Type check command (default: 'mypy .')
    enable_lint: true               # Enable linting (default: true)
    enable_format_check: true       # Enable format checking (default: true)
    enable_type_check: true         # Enable type checking (default: true)
    requirements_file: 'requirements.txt'  # Requirements file (default: 'requirements.txt')
    working_directory: '.'          # Working directory (default: '.')
```

## Custom Testing

If the provided test templates don't meet your needs, you can create custom test jobs:

```yaml
jobs:
  custom-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up environment
        run: # Your custom setup
      - name: Run custom tests
        run: # Your custom test commands
      
  build:
    needs: custom-test
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: ${{ github.event.repository.name }}
      gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
```

## Which Testing Approach to Choose?

| Aspect | Language-Specific Templates | Docker-Only Testing |
|--------|---------------------------|-------------------|
| **Simplicity** | ❌ More workflow setup | ✅ Simpler workflow |
| **Feedback Speed** | ✅ Faster (tests only) | ❌ Slower (full Docker build) |
| **Error Reporting** | ✅ Better test output | ❌ Tests buried in Docker logs |
| **Flexibility** | ✅ Highly configurable | ❌ Limited to Dockerfile |
| **Caching** | ✅ Better dependency caching | ❌ Docker layer caching only |
| **CI Integration** | ✅ Test results in GitHub UI | ❌ No native test reporting |

**Recommendation:** Use language-specific test templates for most services. Only use Docker-only testing for simple services or when you need exact production environment parity.

## Getting Started

1. Choose the appropriate example file for your language/framework
2. Copy it to your microservice repository as `.github/workflows/development.yml` (and optionally `release.yml`)
3. Update the test commands and configuration to match your project
4. Configure the required repository secrets and variables (see main README.md)
5. Push to your development branch to trigger the workflow

## Repository Setup Requirements

Each microservice repository needs:

### Required Variables
- `GCP_PROJECT_ID` - Your Google Cloud project ID

### Required Secrets  
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider
- `GCP_SERVICE_ACCOUNT` - Service account email for WIF

See the main [README.md](../README.md) for detailed setup instructions.
| **CI Integration** | ❌ Limited (no test artifacts) | ✅ Better (test reports, coverage) |
| **Resource Usage** | ❌ More resources | ✅ More efficient |

**Recommendation:**
- **Use Docker-only** for simple services or when you want maximum consistency
- **Use separate test job** for complex services that benefit from fast feedback and detailed CI reporting

## Language Support

The reusable workflow templates automatically handle language-specific requirements:

- **Node.js**: Automatically detects `package.json` and sets up Node.js environment when needed
- **Python**: Works with any Python project using Docker
- **Go**: Works with any Go project using Docker  
- **Other languages**: Any language that can be containerized with Docker

## Usage

1. Copy the appropriate example file to your microservice's `.github/workflows/` directory
2. Rename it appropriately (e.g., `development.yml`, `release.yml`)
3. Customize any optional parameters as needed
4. Commit and push to test the workflow

## Customization Options

### Basic Configuration (Most Common)
```yaml
with:
  service_name: ${{ github.event.repository.name }}  # Automatic
  gcp_project_id: ${{ vars.GCP_PROJECT_ID }}          # Organization variable
  enable_tests: true                                  # Enable/disable testing
  test_command: "npm test"                           # Your test command
```

### Advanced Configuration
```yaml
with:
  service_name: ${{ github.event.repository.name }}
  gcp_project_id: ${{ vars.GCP_PROJECT_ID }}
  dockerfile_path: "docker/Dockerfile"               # Custom Dockerfile location
  build_context: "."                                 # Build context
  node_version: "18"                                 # Node.js version (if using Node.js)
  enable_tests: true
  test_command: "npm run test:ci"                    # Custom test command
  build_command: "npm run build"                     # Pre-Docker build command
  artifact_registry_region: "us-west1"              # Custom region
  artifact_registry_repo: "my-repo"                 # Custom repository
```

## Language-Specific Notes

### Node.js Projects
- Set `enable_tests: true` and `test_command: "npm test"` if you have tests
- Set `build_command: "npm run build"` if you need to build before Docker
- The `node_version` parameter only affects the test/build steps, not the final Docker image

### Python Projects
- Usually set `enable_tests: false` since tests are typically run inside Docker
- The workflow works with any Python project structure
- Handle dependencies and testing in your Dockerfile

### Go Projects
- Usually set `enable_tests: false` since Go tests are typically run during Docker build
- The workflow works with any Go project structure
- Handle compilation and testing in your Dockerfile

### Other Languages
- Set `enable_tests: false` and handle all build/test logic in your Dockerfile
- The workflow templates are language-agnostic and work with any containerized application

## Why No Language-Specific Examples?

The reusable workflow templates handle all language-specific logic internally, so the same workflow configuration works for all languages. The differences are handled by:

1. **Conditional Node.js setup**: Only runs if `enable_tests` is true or `build_command` is specified
2. **Docker-based builds**: The final build always uses Docker, regardless of language
3. **Flexible parameters**: All language-specific needs can be configured through parameters

This approach eliminates duplication and ensures consistency across all microservices.
