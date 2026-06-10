#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

CHART_FILE="charts/vaultwarden/Chart.yaml"

# --- Prérequis ---

if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    print_info "Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub"
    print_info "Run: gh auth login"
    exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

if [ ! -f "$CHART_FILE" ]; then
    print_error "Chart file not found: $CHART_FILE"
    exit 1
fi

if ! git diff-index --quiet HEAD --; then
    print_warning "You have uncommitted changes"
    read -p "Do you want to continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# --- Version ---

CURRENT_VERSION=$(grep '^version:' "$CHART_FILE" | awk '{print $2}')
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

print_info "Current branch : $CURRENT_BRANCH"
print_info "Current version: $CURRENT_VERSION"
echo

read -p "Enter new version number (e.g., 0.2.0): " VERSION

if [[ ! $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Please use semantic versioning (e.g., 0.2.0)"
    exit 1
fi

TAG="v$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    print_error "Tag $TAG already exists"
    exit 1
fi

# --- Release notes ---

echo
print_info "Enter release notes (press Ctrl+D when done):"
RELEASE_NOTES=$(cat)

# --- Confirmation ---

echo
print_info "Summary:"
echo "  - Version : $VERSION (was $CURRENT_VERSION)"
echo "  - Tag     : $TAG"
echo "  - Branch  : $CURRENT_BRANCH"
echo "  - Notes   :"
echo "$RELEASE_NOTES" | sed 's/^/    /'
echo

read -p "Create release? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Release cancelled"
    exit 0
fi

# --- Bump version in Chart.yaml ---

print_info "Bumping version to $VERSION in $CHART_FILE..."
sed -i '' "s/^version: .*/version: $VERSION/" "$CHART_FILE"

# --- Commit + tag ---

print_info "Pulling latest changes..."
git pull origin "$CURRENT_BRANCH"

print_info "Committing version bump..."
git add "$CHART_FILE"
git commit -m "chore: bump chart version to $VERSION"

print_info "Creating tag $TAG..."
git tag -a "$TAG" -m "Release $VERSION"

print_info "Pushing to GitHub..."
git push origin "$CURRENT_BRANCH"
git push origin "$TAG"

# --- GitHub release ---

print_info "Creating GitHub release..."
echo "$RELEASE_NOTES" | gh release create "$TAG" \
    --title "Release $VERSION" \
    --notes-file -

print_info ""
print_info "✓ Release $VERSION created successfully!"
print_info "The GitHub Action will package and publish the Helm chart to gh-pages."
print_info ""
print_info "Once published, install with:"
REPO_URL=$(gh repo view --json url -q .url)
print_info "  helm repo add vaultwarden ${REPO_URL/github.com/raw.githubusercontent.com}/gh-pages"
print_info "  helm install vaultwarden vaultwarden/vaultwarden"
