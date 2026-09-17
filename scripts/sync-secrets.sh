#!/usr/bin/env bash
# ==============================================================================
# Syncs environment variables from a local .env file to GitHub Secrets using 'gh'
# ==============================================================================
set -e

ENV_FILE="${1:-.env}"
MODE="${2:-Individual}"
ENVIRONMENT="${3:-}"
REPO="${4:-}"

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
  echo "[ERROR] GitHub CLI ('gh') is not installed."
  echo "Please install it from https://cli.github.com/ and run 'gh auth login'."
  exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
  echo "[ERROR] You are not logged in to GitHub CLI. Please run 'gh auth login'."
  exit 1
fi

# Check .env file
if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] File '$ENV_FILE' not found."
  exit 1
fi

COMMON_ARGS=()
if [ -n "$REPO" ]; then
  COMMON_ARGS+=(--repo "$REPO")
fi
if [ -n "$ENVIRONMENT" ]; then
  COMMON_ARGS+=(--env "$ENVIRONMENT")
fi

echo "=========================================================="
echo "🚀 Syncing secrets from: $ENV_FILE"
echo "   Mode:                 $MODE"
[ -n "$ENVIRONMENT" ] && echo "   Environment:          $ENVIRONMENT"
[ -n "$REPO" ] && echo "   Repository:           $REPO"
echo "=========================================================="

if [ "$MODE" = "Single" ]; then
  echo "[*] Uploading entire file to secret 'ENV_CONTENT'..."
  gh secret set ENV_CONTENT "${COMMON_ARGS[@]}" < "$ENV_FILE"
  echo "[OK] Successfully set 'ENV_CONTENT' secret."
else
  COUNT=0
  while IFS= read -r line || [ -n "$line" ]; do
    # Strip leading/trailing whitespace
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Ignore comments and blank lines
    if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
      continue
    fi

    # Parse KEY=VALUE
    if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
      KEY="${BASH_REMATCH[1]}"
      VAL="${BASH_REMATCH[2]}"

      # Strip surrounding quotes if present
      VAL=$(echo "$VAL" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

      echo "  -> Setting secret: $KEY"
      gh secret set "$KEY" "${COMMON_ARGS[@]}" --body "$VAL"
      COUNT=$((COUNT + 1))
    fi
  done < "$ENV_FILE"

  echo ""
  echo "[OK] Sync complete! Uploaded $COUNT secret(s) to GitHub."
fi
