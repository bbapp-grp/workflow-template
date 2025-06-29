# Inline CalVer logic for GitHub Actions workflow
set -e

# Configuration
PREFIX="${1:-v}"
FORMAT="${2:-YY.MM.PATCH}"

# Logging functions
log_info() { echo "[INFO] $1" >&2; }
log_success() { echo "[SUCCESS] $1" >&2; }
log_error() { echo "[ERROR] $1" >&2; }

log_info "Creating CalVer tag with prefix: '$PREFIX', format: '$FORMAT'"

# Configure git user for CI
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

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

# Fetch all remote tags
log_info "Fetching all remote tags..."
git fetch --tags --force origin 2>/dev/null || git fetch --tags origin 2>/dev/null || true

# Find all existing tags for this year.month pattern
PATTERN="${PREFIX}${YEAR_MONTH}.*"
log_info "Searching for existing tags with pattern: $PATTERN"

# Get all matching tags
ALL_TAGS=$(git tag -l "$PATTERN" 2>/dev/null || echo "")
if git remote get-url origin >/dev/null 2>&1; then
    REMOTE_TAGS=$(git ls-remote --tags origin 2>/dev/null | \
                  grep "refs/tags/${PREFIX}${YEAR_MONTH}\." | \
                  sed 's|.*refs/tags/||' || echo "")
    if [[ -n "$REMOTE_TAGS" ]]; then
        ALL_TAGS=$(printf "%s\n%s" "$ALL_TAGS" "$REMOTE_TAGS" | sort -u | grep -v '^$' || echo "")
    fi
fi

# Find the highest patch number
HIGHEST_PATCH=0
if [[ -n "$ALL_TAGS" ]]; then
    log_info "Existing tags found for $YEAR_MONTH"
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

# Double-check the tag doesn't exist
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

# Create and push the tag
log_info "Creating tag: $NEW_TAG"
git tag "$NEW_TAG" -m "Release $NEW_TAG [skip ci]"
log_success "Created local tag: $NEW_TAG"

log_info "Pushing tag to remote..."
if git push origin "$NEW_TAG" 2>/dev/null; then
    log_success "Successfully pushed tag to remote: $NEW_TAG"
else
    log_error "Failed to push tag to remote"
    git tag -d "$NEW_TAG" 2>/dev/null || true
    exit 1
fi

# Output the tag
echo "$NEW_TAG"
log_success "CalVer tag creation completed successfully!"
