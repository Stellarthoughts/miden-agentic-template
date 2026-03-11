#!/bin/bash
# Stop hook: runs full verification for both templates on task completion.
# Checks which templates are set up (dependencies installed) and verifies each.

FAILED=0

# --- Project Template: contract integration tests ---
PROJECT_DIR="$CLAUDE_PROJECT_DIR/project-template"
if [[ -d "$PROJECT_DIR/contracts" ]]; then
  echo "=== Verifying project-template contracts ==="
  cd "$PROJECT_DIR" || true

  if cargo test -p integration --release 2>&1; then
    echo "project-template: integration tests passed"
  else
    echo "project-template: integration tests FAILED"
    FAILED=1
  fi
fi

# --- Frontend Template: tests + typecheck + build ---
FRONTEND_DIR="$CLAUDE_PROJECT_DIR/frontend-template"
if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
  echo "=== Verifying frontend-template ==="
  cd "$FRONTEND_DIR" || true

  if npx vitest --run 2>&1; then
    echo "frontend-template: tests passed"
  else
    echo "frontend-template: tests FAILED"
    FAILED=1
  fi

  if npx tsc -b --noEmit 2>&1; then
    echo "frontend-template: type check passed"
  else
    echo "frontend-template: type check FAILED"
    FAILED=1
  fi

  if npx vite build 2>&1; then
    echo "frontend-template: build passed"
  else
    echo "frontend-template: build FAILED"
    FAILED=1
  fi
fi

if [[ $FAILED -eq 0 ]]; then
  echo '{"hookSpecificOutput": {"additionalContext": "Full verification passed for all templates"}}'
  exit 0
else
  echo '{"hookSpecificOutput": {"additionalContext": "Full verification FAILED. Check output above for details."}}'
  exit 2
fi
