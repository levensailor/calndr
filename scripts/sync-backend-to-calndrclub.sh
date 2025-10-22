#!/usr/bin/env bash
set -euo pipefail

# Sync backend code from this monorepo to the dedicated backend repo (calndrclub)
# - Source:   <monorepo>/backend/backend/
# - Target:   <calndrclub_repo>/backend/
#
# This script ensures that only backend files are tracked in the calndrclub repository
# and that frontend code from calndr is not included.

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # monorepo root
SRC_BACKEND_DIR="$SRC_DIR/backend/backend"
SRC_BACKEND_ROOT="$SRC_DIR/backend"
SRC_WORKFLOWS_DIR="$SRC_DIR/backend/.github/workflows"

# Allow override via env var; default to sibling directory
TARGET_REPO_DIR="${CALNDRCLUB_DIR:-$HOME/Dev/calndrclub}"
TARGET_REPO_URL="https://github.com/levensailor/calndrclub.git"
TARGET_BACKEND_DIR="$TARGET_REPO_DIR/backend"

echo "[sync] Source backend directory: $SRC_BACKEND_DIR"
echo "[sync] Target repo directory:    $TARGET_REPO_DIR"

if [ ! -d "$SRC_BACKEND_DIR" ]; then
  echo "[sync] ERROR: Source backend dir not found: $SRC_BACKEND_DIR" >&2
  exit 1
fi

# Workflows are optional but useful to mirror
if [ -d "$SRC_WORKFLOWS_DIR" ]; then
  echo "[sync] Source workflows directory: $SRC_WORKFLOWS_DIR"
fi

# Clone calndrclub if missing
if [ ! -d "$TARGET_REPO_DIR/.git" ]; then
  echo "[sync] Cloning $TARGET_REPO_URL to $TARGET_REPO_DIR ..."
  git clone "$TARGET_REPO_URL" "$TARGET_REPO_DIR"
fi

cd "$TARGET_REPO_DIR"

# Ensure on main branch and up to date
git fetch origin --prune
git checkout 
git pull --rebase origin main

# Ensure backend dir exists
mkdir -p "$TARGET_BACKEND_DIR"
mkdir -p "$TARGET_REPO_DIR/.github/workflows"

# Clear any frontend files that might have been accidentally synced
find "$TARGET_REPO_DIR" -type f -not -path "*/\.*" -not -path "*/backend/*" -not -path "*/.github/workflows/*" -not -name "README.md" -not -name "CHANGELOG.md" -not -name "LICENSE" | grep -v -E '(deploy|setup|terraform|nginx)' | xargs rm -f 2>/dev/null || true

echo "[sync] Rsyncing files into $TARGET_BACKEND_DIR ..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='venv' \
  --exclude='.venv' \
  --exclude='logs' \
  --exclude='frontend' \
  --exclude='vue-app' \
  --exclude='ios' \
  "$SRC_BACKEND_DIR/" "$TARGET_BACKEND_DIR/"

# Copy Dockerfile and other root backend files
echo "[sync] Copying Dockerfile and other root backend files..."
cp "$SRC_BACKEND_ROOT/Dockerfile" "$TARGET_REPO_DIR/backend/" 2>/dev/null || true
cp "$SRC_BACKEND_ROOT/requirements.txt" "$TARGET_REPO_DIR/backend/" 2>/dev/null || true

if [ -d "$SRC_WORKFLOWS_DIR" ]; then
  echo "[sync] Rsyncing workflows into $TARGET_REPO_DIR/.github/workflows ..."
  rsync -av --delete \
    "$SRC_WORKFLOWS_DIR/" "$TARGET_REPO_DIR/.github/workflows/"
fi

# Commit if there are changes
if ! git diff --quiet; then
  MONOREPO_HEAD_SHA=$(git -C "$SRC_DIR" rev-parse --short HEAD || echo "unknown")
  COMMIT_MSG="chore(sync): mirror backend from monorepo (calndr) @ $MONOREPO_HEAD_SHA"
  echo "[sync] Committing changes: $COMMIT_MSG"
  
  # Only add backend files and workflows, not frontend files
  git add backend .github/workflows || true
  
  # Check if there are any staged changes
  if git diff --cached --quiet; then
    echo "[sync] No backend changes to commit."
  else
    git commit -m "$COMMIT_MSG"
    echo "[sync] Pushing to origin/main ..."
    git push origin main
  fi
else
  echo "[sync] No changes to commit."
fi

echo "[sync] Done."


