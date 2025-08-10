#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-backend-to-calndrclub.sh"

if [ ! -x "$SYNC_SCRIPT" ]; then
  echo "[hooks] ERROR: Sync script not executable: $SYNC_SCRIPT" >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR"

create_post_commit() {
  cat > "$HOOKS_DIR/post-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-backend-to-calndrclub.sh"

if [ ! -x "$SYNC_SCRIPT" ]; then
  exit 0
fi

# Get files changed in this commit
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD || true)

if echo "$CHANGED_FILES" | grep -qE '^backend/backend/'; then
  echo "[post-commit] Backend changes detected; syncing to calndrclub..."
  "$SYNC_SCRIPT"
fi
EOF
  chmod +x "$HOOKS_DIR/post-commit"
}

create_post_merge() {
  cat > "$HOOKS_DIR/post-merge" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-backend-to-calndrclub.sh"

if [ ! -x "$SYNC_SCRIPT" ]; then
  exit 0
fi

# Check merged range (FETCH_HEAD may not exist depending on merge type)
# Fallback to diff against HEAD~1
RANGE_DIFF=$(git diff --name-only HEAD~1..HEAD || true)

if echo "$RANGE_DIFF" | grep -qE '^backend/backend/'; then
  echo "[post-merge] Backend changes detected; syncing to calndrclub..."
  "$SYNC_SCRIPT"
fi
EOF
  chmod +x "$HOOKS_DIR/post-merge"
}

create_post_checkout() {
  cat > "$HOOKS_DIR/post-checkout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-backend-to-calndrclub.sh"

if [ ! -x "$SYNC_SCRIPT" ]; then
  exit 0
fi

# Only act when switching branches (3rd arg is 1)
if [ "${3:-0}" = "1" ]; then
  # Compare previous HEAD to new HEAD
  PREV_REF="${1:-}"
  NEW_REF="${2:-}"
  if [ -n "$PREV_REF" ] && [ -n "$NEW_REF" ]; then
    RANGE_DIFF=$(git diff --name-only "$PREV_REF".."$NEW_REF" || true)
    if echo "$RANGE_DIFF" | grep -qE '^backend/backend/'; then
      echo "[post-checkout] Backend changes detected; syncing to calndrclub..."
      "$SYNC_SCRIPT"
    fi
  fi
fi
EOF
  chmod +x "$HOOKS_DIR/post-checkout"
}

create_post_commit
create_post_merge
create_post_checkout

echo "[hooks] Installed backend sync hooks in $HOOKS_DIR"


