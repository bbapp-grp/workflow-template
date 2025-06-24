#!/bin/bash

# BBApp Workflow Validation Script
# This script validates that a microservice repository is ready for the reusable workflows

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

# Validation counters
PASSED=0
WARNINGS=0
FAILED=0

# Function to increment counters
pass() {
    print_success "$1"
    ((PASSED++))
}

warn() {
    print_warning "$1"
    ((WARNINGS++))
}

fail() {
    print_error "$1"
    ((FAILED++))
}

echo "BBApp Workflow Validation"
echo "========================="
echo

# Check if we're in a git repository
print_check "Checking if this is a git repository..."
if [[ -d .git ]]; then
    pass "Git repository detected"
else
    fail "Not a git repository - workflows require git"
fi

# Check for Dockerfile
print_check "Checking for Dockerfile..."
if [[ -f "Dockerfile" ]]; then
    pass "Dockerfile found in root directory"
elif [[ -f "docker/Dockerfile" ]]; then
    warn "Dockerfile found in docker/ directory - you'll need to set dockerfile_path"
else
    # Look for Dockerfiles in subdirectories
    dockerfiles=$(find . -name "Dockerfile" -type f | head -5)
    if [[ -n "$dockerfiles" ]]; then
        warn "Dockerfile(s) found in subdirectories - you'll need to set dockerfile_path:"
        echo "$dockerfiles" | sed 's/^/     /'
    else
        fail "No Dockerfile found - required for container builds"
    fi
fi

# Check for workflow files
print_check "Checking existing workflow files..."
if [[ -d ".github/workflows" ]]; then
    workflow_files=$(ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | wc -l)
    if [[ $workflow_files -gt 0 ]]; then
        warn "Existing workflow files found - they will be backed up during migration"
        ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | sed 's/^/     /'
    else
        pass "Workflows directory exists but is empty"
    fi
else
    pass "No existing workflows directory - will be created"
fi

# Check for package.json (Node.js projects)
print_check "Checking for Node.js project indicators..."
if [[ -f "package.json" ]]; then
    pass "package.json found - Node.js project detected"
    
    # Check for test script
    if grep -q '"test"' package.json; then
        if grep -q '"test".*"echo.*no test.*exit 1"' package.json; then
            warn "Default test script found - consider adding real tests or disabling test execution"
        else
            pass "Test script configured in package.json"
        fi
    else
        warn "No test script in package.json - consider adding tests or disabling test execution"
    fi
    
    # Check for build script
    if grep -q '"build"' package.json; then
        pass "Build script found in package.json"
    else
        warn "No build script in package.json - may not be needed depending on your setup"
    fi
else
    pass "No package.json found - not a Node.js project"
fi

# Check for Python project indicators
print_check "Checking for Python project indicators..."
python_files=false
if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "Pipfile" ]]; then
    python_files=true
fi

if [[ $python_files == true ]]; then
    pass "Python project files detected"
else
    # Check for .py files
    py_count=$(find . -name "*.py" -type f | head -5 | wc -l)
    if [[ $py_count -gt 0 ]]; then
        pass "Python source files detected"
    fi
fi

# Check for Go project indicators
print_check "Checking for Go project indicators..."
if [[ -f "go.mod" ]] || [[ -f "go.sum" ]]; then
    pass "Go module files detected"
else
    # Check for .go files
    go_count=$(find . -name "*.go" -type f | head -5 | wc -l)
    if [[ $go_count -gt 0 ]]; then
        warn "Go source files found but no go.mod - consider using Go modules"
    fi
fi

# Check GitHub CLI availability for secrets
print_check "Checking GitHub CLI availability..."
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        pass "GitHub CLI is available and authenticated"
        
        # Check repository secrets
        print_check "Checking repository secrets..."
        secrets_output=$(gh secret list 2>/dev/null || echo "")
        
        if echo "$secrets_output" | grep -q "WIF_PROVIDER"; then
            pass "WIF_PROVIDER secret is configured"
        else
            fail "WIF_PROVIDER secret not found - required for authentication"
        fi
        
        if echo "$secrets_output" | grep -q "WIF_SERVICE_ACCOUNT"; then
            pass "WIF_SERVICE_ACCOUNT secret is configured"
        else
            fail "WIF_SERVICE_ACCOUNT secret not found - required for authentication"
        fi
    else
        warn "GitHub CLI is available but not authenticated"
    fi
else
    warn "GitHub CLI not available - cannot check repository secrets"
fi

# Check for branch structure
print_check "Checking branch structure..."
if git show-ref --verify --quiet refs/heads/main; then
    pass "main branch exists"
else
    if git show-ref --verify --quiet refs/heads/master; then
        warn "master branch exists instead of main - consider renaming to main"
    else
        fail "Neither main nor master branch found"
    fi
fi

if git show-ref --verify --quiet refs/heads/develop; then
    pass "develop branch exists"
else
    warn "develop branch not found - you may want to create it for development workflows"
fi

# Check current branch
current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
print_info "Current branch: $current_branch"

# Check for remote repository
print_check "Checking remote repository..."
if git remote get-url origin &>/dev/null; then
    remote_url=$(git remote get-url origin)
    if [[ "$remote_url" == *"github.com"* ]]; then
        if [[ "$remote_url" == *"bbapp-grp"* ]]; then
            pass "Repository is in bbapp-grp organization on GitHub"
        else
            warn "Repository is on GitHub but not in bbapp-grp organization"
            echo "     Remote: $remote_url"
        fi
    else
        fail "Repository is not on GitHub - workflows require GitHub"
        echo "     Remote: $remote_url"
    fi
else
    fail "No remote repository configured"
fi

# Check Docker build capability
print_check "Checking Docker build capability..."
if command -v docker &> /dev/null; then
    pass "Docker is available for local testing"
    
    # Try to validate Dockerfile syntax (basic check)
    if [[ -f "Dockerfile" ]]; then
        if docker build --no-cache --dry-run . &>/dev/null; then
            pass "Dockerfile syntax appears valid"
        else
            warn "Dockerfile may have syntax issues - test locally before pushing"
        fi
    fi
else
    warn "Docker not available - cannot test builds locally"
fi

# Summary
echo
echo "Validation Summary"
echo "=================="
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo

if [[ $FAILED -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        print_success "Repository is ready for workflow migration!"
    else
        print_warning "Repository is mostly ready - address warnings for best results"
    fi
    echo
    echo "Next steps:"
    echo "1. Run the migration script: ./migrate.sh --service-name YOUR_SERVICE_NAME"
    echo "2. Review and customize the generated workflow files"
    echo "3. Test with a push to develop branch"
else
    print_error "Repository has issues that need to be addressed before migration"
    echo
    echo "Required fixes:"
    echo "- Ensure this is a git repository with GitHub remote"
    echo "- Add a Dockerfile for container builds"
    echo "- Configure WIF_PROVIDER and WIF_SERVICE_ACCOUNT secrets"
fi

exit $FAILED
