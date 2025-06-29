#!/bin/bash

# Robust CalVer Tag Creator for CI/CD
# Handles tag conflicts by finding the next available patch number
# Usage: ./create-calver-tag.sh [--prefix=PREFIX] [--format=FORMAT]

set -e

# Default configuration
PREFIX="v"
FORMAT="YY.MM.PATCH"  # YY.MM.PATCH or YYYY.MM.PATCH

# Logging functions for CI compatibility
log_info() { echo "[INFO] $1" >&2; }
log_success() { echo "[SUCCESS] $1" >&2; }
log_warning() { echo "[WARNING] $1" >&2; }
log_error() { echo "[ERROR] $1" >&2; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --format=*)
            FORMAT="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--prefix=PREFIX] [--format=FORMAT]"
            echo "  --prefix     Tag prefix (default: v)"
            echo "  --format     Format: YY.MM.PATCH or YYYY.MM.PATCH (default: YY.MM.PATCH)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Creating CalVer tag with prefix: '$PREFIX', format: '$FORMAT'"

# Ensure we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a git repository"
    exit 1
fi

# Configure git user if not set (important for CI)
if ! git config user.name >/dev/null 2>&1; then
    log_info "Setting git user for CI environment"
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
fi

# Get current date components
if [[ "$FORMAT" == "YYYY.MM.PATCH" ]]; then
    YEAR=$(date +%Y)
    MONTH=$(date +%m)
else
    YEAR=$(date +%y)
    MONTH=$(date +%m)
fi

YEAR_MONTH="${YEAR}.${MONTH}"
log_info "Current period: $YEAR_MONTH"

# Fetch all remote tags to ensure we have the latest (critical for CI)
log_info "Fetching all remote tags..."
git fetch --tags --force origin 2>/dev/null || git fetch --tags origin 2>/dev/null || true

# Find all existing tags for this year.month pattern
PATTERN="${PREFIX}${YEAR_MONTH}.*"
log_info "Searching for existing tags with pattern: $PATTERN"

# Get all matching tags (both local and remote)
ALL_TAGS=""

# Get local tags
LOCAL_TAGS=$(git tag -l "$PATTERN" 2>/dev/null || echo "")
if [[ -n "$LOCAL_TAGS" ]]; then
    log_info "Found local tags: $LOCAL_TAGS"
    ALL_TAGS="$LOCAL_TAGS"
fi

# Get remote tags to ensure we don't miss any
if git remote get-url origin >/dev/null 2>&1; then
    REMOTE_TAGS=$(git ls-remote --tags origin 2>/dev/null | \
                  grep "refs/tags/${PREFIX}${YEAR_MONTH}\." | \
                  sed 's|.*refs/tags/||' || echo "")
    if [[ -n "$REMOTE_TAGS" ]]; then
        log_info "Found remote tags: $REMOTE_TAGS"
        ALL_TAGS=$(printf "%s\n%s" "$ALL_TAGS" "$REMOTE_TAGS" | sort -u | grep -v '^$' || echo "")
    fi
fi

# Find the highest patch number
HIGHEST_PATCH=0
if [[ -n "$ALL_TAGS" ]]; then
    log_info "All existing tags for $YEAR_MONTH"
    # Log each tag individually to avoid output formatting issues
    while read -r tag; do
        if [[ -n "$tag" ]]; then
            log_info "Existing tag: $tag"
        fi
    done <<< "$ALL_TAGS"
    
    # Extract patch numbers and find the highest
    while read -r tag; do
        if [[ -n "$tag" && "$tag" =~ ^${PREFIX}${YEAR_MONTH}\.([0-9]+)$ ]]; then
            PATCH="${BASH_REMATCH[1]}"
            if [[ "$PATCH" -gt "$HIGHEST_PATCH" ]]; then
                HIGHEST_PATCH="$PATCH"
            fi
        fi
    done <<< "$ALL_TAGS"
    
    log_info "Highest existing patch number: $HIGHEST_PATCH"
else
    log_info "No existing tags found for $YEAR_MONTH"
fi

# Generate next patch number
NEXT_PATCH=$((HIGHEST_PATCH + 1))
NEW_TAG="${PREFIX}${YEAR_MONTH}.${NEXT_PATCH}"

log_success "Generated new tag: $NEW_TAG"

# Double-check the tag doesn't exist (race condition protection)
if git tag -l "$NEW_TAG" | grep -q "^${NEW_TAG}$" 2>/dev/null; then
    log_error "Tag $NEW_TAG already exists locally!"
    exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
    if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/${NEW_TAG}$"; then
        log_error "Tag $NEW_TAG already exists on remote!"
        exit 1
    fi
fi

# Create the tag
log_info "Creating tag: $NEW_TAG"
if ! git tag "$NEW_TAG" -m "Release $NEW_TAG [skip ci]"; then
    log_error "Failed to create tag: $NEW_TAG"
    exit 1
fi

log_success "Created local tag: $NEW_TAG"

# Push to remote if available
if git remote get-url origin >/dev/null 2>&1; then
    log_info "Pushing tag to remote..."
    if git push origin "$NEW_TAG" 2>/dev/null; then
        log_success "Successfully pushed tag to remote: $NEW_TAG"
    else
        log_error "Failed to push tag to remote"
        # Clean up local tag
        git tag -d "$NEW_TAG" 2>/dev/null || true
        exit 1
    fi
else
    log_warning "No remote origin configured - tag created locally only"
fi

# Export for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    VERSION_WITHOUT_PREFIX="${NEW_TAG#$PREFIX}"
    echo "version=${VERSION_WITHOUT_PREFIX}" >> "$GITHUB_OUTPUT"
    echo "full_tag=${NEW_TAG}" >> "$GITHUB_OUTPUT"
    echo "calver_tag=${NEW_TAG}" >> "$GITHUB_OUTPUT"
    log_info "Exported variables to GITHUB_OUTPUT"
fi

# Output the tag for script capture
echo "$NEW_TAG"
log_success "CalVer tag creation completed successfully!"
