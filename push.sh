#!/usr/bin/env bash
# =============================================================================
# push.sh — Auto Push Script for gitops-fullstack
# Usage: ./push.sh [commit message]
# Example: ./push.sh "update frontend image tag"
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UMBRELLA_CHART="$REPO_ROOT/charts/full-stack-app"

log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   GitOps Fullstack — Auto Push Script      ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── 1. Check required tools ──────────────────────────────────────────────────
log "Checking required tools..."
for tool in git helm; do
  command -v "$tool" &>/dev/null || error "'$tool' is not installed or not in PATH"
done
success "All tools found (git, helm)"

# ── 2. Make sure we're in the git repo ───────────────────────────────────────
cd "$REPO_ROOT"
git rev-parse --is-inside-work-tree &>/dev/null || error "Not inside a git repository!"

# ── 3. Show current branch ───────────────────────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD)
log "Current branch: ${YELLOW}${BRANCH}${NC}"

# ── 4. Run helm dependency update ────────────────────────────────────────────
log "Updating Helm dependencies for full-stack-app..."
helm dependency update "$UMBRELLA_CHART" || error "helm dependency update failed"
success "Helm dependencies updated (.tgz files refreshed)"

# ── 5. Stage all changes ─────────────────────────────────────────────────────
log "Staging all changes..."
git add .

# Check if there's anything to commit
if git diff --cached --quiet; then
  warn "No changes to commit. Repository is already up to date."
  echo ""
  exit 0
fi

# Show staged files summary
echo ""
echo -e "${YELLOW}Staged changes:${NC}"
git diff --cached --name-status
echo ""

# ── 6. Build commit message ──────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ -n "${1:-}" ]; then
  COMMIT_MSG="$1"
else
  COMMIT_MSG="chore: update helm charts [${TIMESTAMP}]"
fi

log "Commit message: \"${COMMIT_MSG}\""

# ── 7. Commit ────────────────────────────────────────────────────────────────
git commit -m "$COMMIT_MSG"
success "Committed changes"

# ── 8. Push to remote ────────────────────────────────────────────────────────
log "Pushing to origin/${BRANCH}..."
git push origin "$BRANCH" || error "git push failed — check your remote connection or credentials"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅  Successfully pushed to origin/${BRANCH}  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ArgoCD will now detect the change and sync automatically."
echo -e "  Branch : ${YELLOW}${BRANCH}${NC}"
echo -e "  Commit : ${YELLOW}$(git rev-parse --short HEAD)${NC}"
echo -e "  Time   : ${YELLOW}${TIMESTAMP}${NC}"
echo ""
