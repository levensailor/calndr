#!/usr/bin/env bash
set -euo pipefail

# Sync backend code from this monorepo to the dedicated backend repo (calndrclub)
# - Source:   <monorepo>/backend/backend/
# - Target:   <calndrclub_repo>/backend/

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # monorepo root
SRC_BACKEND_DIR="$SRC_DIR/backend/backend"
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
git checkout main
git pull --rebase origin main

# Ensure backend dir exists
mkdir -p "$TARGET_BACKEND_DIR"
mkdir -p "$TARGET_REPO_DIR/.github/workflows"

echo "[sync] Rsyncing files into $TARGET_BACKEND_DIR ..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='venv' \
  --exclude='.venv' \
  --exclude='logs' \
  "$SRC_BACKEND_DIR/" "$TARGET_BACKEND_DIR/"

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
  git add backend .github/workflows || true
  git commit -m "$COMMIT_MSG"
  echo "[sync] Pushing to origin/main ..."
  git push origin main
else
  echo "[sync] No changes to commit."
fi

echo "[sync] Done."


