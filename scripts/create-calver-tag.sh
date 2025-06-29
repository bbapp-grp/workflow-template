#!/bin/bash

# Robust CalVer Tag Creator for CI/CD
# Handles tag conflicts by finding the next available patch number
# Usage: ./create-calver-tag.sh [--prefix=PREFIX] [--format=FORMAT]

set -e

# Default configuration
PREFIX="v"
FORMAT="YY.MM.PATCH"  # YY.MM.PATCH or YYYY.MM.PATCH

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
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🏷️ Creating CalVer tag with prefix: '$PREFIX', format: '$FORMAT'"

# Ensure we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Configure git user if not set (important for CI)
if ! git config user.name >/dev/null 2>&1; then
    echo "🤖 Setting git user for CI environment"
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
echo "📅 Current period: $YEAR_MONTH"

# Fetch all remote tags to ensure we have the latest (critical for CI)
echo "📥 Fetching all remote tags..."
git fetch --tags --force origin 2>/dev/null || git fetch --tags origin 2>/dev/null || true

# Find all existing tags for this year.month pattern
PATTERN="${PREFIX}${YEAR_MONTH}.*"
echo "🔍 Searching for existing tags with pattern: $PATTERN"

# Get all matching tags (both local and remote)
ALL_TAGS=""

# Get local tags
LOCAL_TAGS=$(git tag -l "$PATTERN" 2>/dev/null || echo "")
if [[ -n "$LOCAL_TAGS" ]]; then
    echo "📍 Found local tags: $LOCAL_TAGS"
    ALL_TAGS="$LOCAL_TAGS"
fi

# Get remote tags to ensure we don't miss any
if git remote get-url origin >/dev/null 2>&1; then
    REMOTE_TAGS=$(git ls-remote --tags origin 2>/dev/null | \
                  grep "refs/tags/${PREFIX}${YEAR_MONTH}\." | \
                  sed 's|.*refs/tags/||' || echo "")
    if [[ -n "$REMOTE_TAGS" ]]; then
        echo "�� Found remote tags: $REMOTE_TAGS"
        ALL_TAGS=$(printf "%s\n%s" "$ALL_TAGS" "$REMOTE_TAGS" | sort -u | grep -v '^$' || echo "")
    fi
fi

# Find the highest patch number
HIGHEST_PATCH=0
if [[ -n "$ALL_TAGS" ]]; then
    echo "📋 All existing tags for $YEAR_MONTH:"
    echo "$ALL_TAGS" | while read -r tag; do
        if [[ -n "$tag" ]]; then
            echo "  - $tag"
        fi
    done
    
    # Extract patch numbers and find the highest
    while read -r tag; do
        if [[ -n "$tag" && "$tag" =~ ^${PREFIX}${YEAR_MONTH}\.([0-9]+)$ ]]; then
            PATCH="${BASH_REMATCH[1]}"
            if [[ "$PATCH" -gt "$HIGHEST_PATCH" ]]; then
                HIGHEST_PATCH="$PATCH"
            fi
        fi
    done <<< "$ALL_TAGS"
    
    echo "🔢 Highest existing patch number: $HIGHEST_PATCH"
else
    echo "✨ No existing tags found for $YEAR_MONTH"
fi

# Generate next patch number
NEXT_PATCH=$((HIGHEST_PATCH + 1))
NEW_TAG="${PREFIX}${YEAR_MONTH}.${NEXT_PATCH}"

echo "🎯 Generated new tag: $NEW_TAG"

# Double-check the tag doesn't exist (race condition protection)
if git tag -l "$NEW_TAG" | grep -q "^${NEW_TAG}$" 2>/dev/null; then
    echo "❌ Error: Tag $NEW_TAG already exists locally!"
    exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
    if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/${NEW_TAG}$"; then
        echo "❌ Error: Tag $NEW_TAG already exists on remote!"
        exit 1
    fi
fi

# Create the tag
echo "📦 Creating tag: $NEW_TAG"
if ! git tag "$NEW_TAG"; then
    echo "❌ Error: Failed to create tag: $NEW_TAG"
    exit 1
fi

echo "✅ Created local tag: $NEW_TAG"

# Push to remote if available
if git remote get-url origin >/dev/null 2>&1; then
    echo "🚀 Pushing tag to remote..."
    if git push origin "$NEW_TAG" 2>/dev/null; then
        echo "✅ Successfully pushed tag to remote: $NEW_TAG"
    else
        echo "❌ Error: Failed to push tag to remote"
        # Clean up local tag
        git tag -d "$NEW_TAG" 2>/dev/null || true
        exit 1
    fi
else
    echo "⚠️ Warning: No remote origin configured - tag created locally only"
fi

# Export for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    VERSION_WITHOUT_PREFIX="${NEW_TAG#$PREFIX}"
    echo "version=${VERSION_WITHOUT_PREFIX}" >> "$GITHUB_OUTPUT"
    echo "full_tag=${NEW_TAG}" >> "$GITHUB_OUTPUT"
    echo "calver_tag=${NEW_TAG}" >> "$GITHUB_OUTPUT"
    echo "📝 Exported variables to GITHUB_OUTPUT"
fi

# Output the tag for script capture
echo "$NEW_TAG"
echo "🎉 CalVer tag creation completed successfully!"
