#!/bin/bash

# BBApp Workflow Migration Script
# This script helps migrate a microservice to use the reusable workflow templates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
SERVICE_NAME=""
LANGUAGE=""
TEST_PATTERN=""

# Helper functions
print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}  BBApp Workflow Migration Tool  ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --project-id PROJECT_ID    GCP Project ID"
    echo "  -s, --service-name SERVICE_NAME Service name (defaults to repo name)"
    echo "  -l, --language LANGUAGE        Language (nodejs, golang, python, other)"
    echo "  -t, --test-pattern PATTERN     Test pattern (template, docker, custom)"
    echo "  -h, --help                     Show this help message"
    echo ""
    echo "Test Patterns:"
    echo "  template  - Use language-specific test templates (recommended)"
    echo "  docker    - Handle tests in Dockerfile only"
    echo "  custom    - Keep existing test setup"
    echo ""
    echo "Example:"
    echo "  $0 --project-id bbapp-dev-440805 --language nodejs --test-pattern template"
}

detect_language() {
    if [[ -f "package.json" ]]; then
        echo "nodejs"
    elif [[ -f "go.mod" ]] || [[ -f "go.sum" ]]; then
        echo "golang"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
        echo "python"
    else
        echo "other"
    fi
}

create_nodejs_workflow() {
    local file_path="$1"
    local workflow_type="$2"  # development or release
    local branch="develop"
    local template="development-build.yml"
    
    if [[ "$workflow_type" == "release" ]]; then
        branch="main"
        template="release-build.yml"
    fi
    
    if [[ "$TEST_PATTERN" == "template" ]]; then
        cat > "$file_path" << EOF
name: $(echo "$workflow_type" | sed 's/./\U&/') Build

on:
  push:
    branches: [ $branch ]

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
    uses: bbapp-grp/workflow-template/.github/workflows/$template@main
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.GCP_SERVICE_ACCOUNT }}
EOF
    else
        cat > "$file_path" << EOF
name: $(echo "$workflow_type" | sed 's/./\U&/') Build

on:
  push:
    branches: [ $branch ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/$template@main
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.GCP_SERVICE_ACCOUNT }}
EOF
    fi
}

create_golang_workflow() {
    local file_path="$1"
    local workflow_type="$2"
    local branch="develop"
    local template="development-build.yml"
    
    if [[ "$workflow_type" == "release" ]]; then
        branch="main"
        template="release-build.yml"
    fi
    
    if [[ "$TEST_PATTERN" == "template" ]]; then
        cat > "$file_path" << EOF
name: $(echo "$workflow_type" | sed 's/./\U&/') Build

on:
  push:
    branches: [ $branch ]

jobs:
  test:
    name: Run Tests
    uses: bbapp-grp/workflow-template/.github/workflows/golang-test.yml@main
    with:
      go_version: '1.21'
      test_command: 'go test ./...'
      lint_command: 'golangci-lint run'
      vet_command: 'go vet ./...'
      enable_lint: true
      enable_vet: true
      enable_race_detection: true

  build:
    name: Build and Push
    needs: test
    if: success()
    uses: bbapp-grp/workflow-template/.github/workflows/$template@main
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.GCP_SERVICE_ACCOUNT }}
EOF
    else
        cat > "$file_path" << EOF
name: $(echo "$workflow_type" | sed 's/./\U&/') Build

on:
  push:
    branches: [ $branch ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/$template@main
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
    secrets:
      WIF_PROVIDER: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.GCP_SERVICE_ACCOUNT }}
EOF
    fi
}
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOFlopment Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: \${{ github.event.repository.name }}
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOF0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
LANGUAGE="nodejs"
BACKUP_EXISTING=true
DRY_RUN=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
BBApp Workflow Migration Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --language <lang>       Programming language (nodejs, python, go) [default: nodejs]
    --no-backup            Don't backup existing workflow files
    --dry-run              Show what would be done without making changes
    --help                 Show this help message

EXAMPLES:
    # Basic Node.js service
    $0

    # Python service
    $0 --language python

    # Go service with no backup
    $0 --language go --no-backup

    # Dry run to see what would happen
    $0 --dry-run

NOTES:
    - This script should be run from the root of your microservice repository
    - Service name is automatically detected from the repository name
    - Existing workflow files will be backed up unless --no-backup is specified
    - You'll need to manually configure secrets (WIF_PROVIDER, WIF_SERVICE_ACCOUNT)
    - After migration, test the workflows with a push to develop branch

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_EXISTING=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments and get repository name
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
if [[ -z "$REPO_NAME" ]]; then
    print_error "Could not determine repository name. Are you in a git repository?"
    exit 1
fi

print_info "Detected repository name: $REPO_NAME"

# Validate language
if [[ ! "$LANGUAGE" =~ ^(nodejs|python|go)$ ]]; then
    print_error "Unsupported language: $LANGUAGE. Supported: nodejs, python, go"
    exit 1
fi

# Check if we're in a git repository
if [[ ! -d .git ]]; then
    print_error "This script must be run from the root of a git repository"
    exit 1
fi

# Check if .github/workflows directory exists
WORKFLOWS_DIR=".github/workflows"

print_info "Starting migration for repository: $REPO_NAME (language: $LANGUAGE)"

if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No changes will be made"
fi

# Create workflows directory if it doesn't exist
if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    print_info "Creating .github/workflows directory"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$WORKFLOWS_DIR"
    fi
fi

# Function to backup existing files
backup_file() {
    local file="$1"
    if [[ -f "$file" && "$BACKUP_EXISTING" == true ]]; then
        local backup_file="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Backing up $file to $backup_file"
        if [[ "$DRY_RUN" == false ]]; then
            cp "$file" "$backup_file"
        fi
    fi
}

# Function to create workflow file
create_workflow() {
    local workflow_type="$1"
    local file_path="$WORKFLOWS_DIR/${workflow_type}.yml"
    
    backup_file "$file_path"
    
    print_info "Creating $workflow_type workflow: $file_path"
    
    if [[ "$DRY_RUN" == false ]]; then
        case "$LANGUAGE" in
            nodejs)
                if [[ "$workflow_type" == "development" ]]; then
                    cat > "$file_path" << EOF
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "$SERVICE_NAME"
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOF
                else
                    cat > "$file_path" << EOF
name: Release Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/release-build.yml@main
    with:
      service_name: "$SERVICE_NAME"
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: true
      test_command: "npm test"
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOF
                fi
                ;;
            python|go)
                if [[ "$workflow_type" == "development" ]]; then
                    cat > "$file_path" << EOF
name: Development Build

on:
  push:
    branches: [ develop ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/development-build.yml@main
    with:
      service_name: "$SERVICE_NAME"
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: false  # Tests handled in Dockerfile
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOF
                else
                    cat > "$file_path" << EOF
name: Release Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: bbapp-grp/workflow-template/.github/workflows/release-build.yml@main
    with:
      service_name: "$SERVICE_NAME"
      gcp_project_id: \${{ vars.GCP_PROJECT_ID }}
      enable_tests: false  # Tests handled in Dockerfile
    secrets:
      WIF_PROVIDER: \${{ secrets.WIF_PROVIDER }}
      WIF_SERVICE_ACCOUNT: \${{ secrets.WIF_SERVICE_ACCOUNT }}
EOF
                fi
                ;;
        esac
    fi
}

# Create both workflows
create_workflow "development"
create_workflow "release"

# Check for existing secrets
print_info "Checking repository secrets..."

# Function to check if we can access GitHub CLI
check_github_cli() {
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

if check_github_cli; then
    print_info "Checking existing repository secrets..."
    
    # Check for required secrets
    secrets_output=$(gh secret list 2>/dev/null || echo "")
    
    if echo "$secrets_output" | grep -q "WIF_PROVIDER"; then
        print_success "WIF_PROVIDER secret found"
    else
        print_warning "WIF_PROVIDER secret not found - you'll need to add this"
    fi
    
    if echo "$secrets_output" | grep -q "WIF_SERVICE_ACCOUNT"; then
        print_success "WIF_SERVICE_ACCOUNT secret found"
    else
        print_warning "WIF_SERVICE_ACCOUNT secret not found - you'll need to add this"
    fi
else
    print_warning "GitHub CLI not available or not authenticated - cannot check secrets"
fi

# Success message
print_success "Migration completed!"

# Next steps
cat << EOF

${GREEN}Next Steps:${NC}

1. ${BLUE}Verify Secrets:${NC}
   Ensure these repository secrets are configured:
   - WIF_PROVIDER: Your Workload Identity Federation provider
   - WIF_SERVICE_ACCOUNT: Your service account email

2. ${BLUE}Review Workflows:${NC}
   Check the generated workflow files in .github/workflows/:
   - development.yml
   - release.yml

3. ${BLUE}Customize if Needed:${NC}
   You can customize the workflows by adding parameters like:
   - dockerfile_path (if not in root)
   - build_command (for pre-Docker builds)
   - test_command (custom test commands)

4. ${BLUE}Test the Workflows:${NC}
   - Make a small change and push to 'develop' branch
   - Verify image is built and pushed to Artifact Registry
   - Test release process by merging to 'main' branch

5. ${BLUE}Set Up Secrets (if needed):${NC}
   gh secret set WIF_PROVIDER --body "your-wif-provider"
   gh secret set WIF_SERVICE_ACCOUNT --body "your-service-account@project.iam.gserviceaccount.com"

${YELLOW}Troubleshooting:${NC}
- If builds fail, check the GitHub Actions logs
- Verify your Dockerfile builds correctly locally
- Ensure Artifact Registry repository exists
- Check WIF and service account permissions

For more information, see: https://github.com/bbapp-grp/workflow-template

EOF

if [[ "$DRY_RUN" == true ]]; then
    print_warning "This was a dry run - no files were actually created or modified"
fi
