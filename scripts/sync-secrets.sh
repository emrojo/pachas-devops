#!/usr/bin/env bash
# ==============================================================================
# Syncs environment variables from a local .env file to GitHub Secrets using 'gh'
# Supports reading SSH_KEY from a local file path (SSH_KEY_PATH).
# ==============================================================================
set -e

ENV_FILE="${1:-.env}"
MODE="${2:-Individual}"
ENVIRONMENT="${3:-}"
REPO="${4:-}"
KEY_PATH="${5:-}"

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

# Check if SSH_KEY_PATH is specified in .env or via argument
if [ -z "$KEY_PATH" ]; then
  # Extract SSH_KEY_PATH or SSH_KEY_FILE from .env if present
  KEY_PATH=$(grep -E '^(SSH_KEY_PATH|SSH_KEY_FILE)=' "$ENV_FILE" | head -n 1 | cut -d '=' -f2- | tr -d '"' | tr -d "'")
fi

if [ -n "$KEY_PATH" ]; then
  # Expand tilde (~) if present
  KEY_PATH="${KEY_PATH/#\~/$HOME}"
  if [ -f "$KEY_PATH" ]; then
    echo "[+] Reading SSH key file from: $KEY_PATH"
    gh secret set SSH_KEY "${COMMON_ARGS[@]}" < "$KEY_PATH"
    echo "  -> Secret 'SSH_KEY' successfully set from file."
  else
    echo "[ERROR] Specified SSH key file not found: $KEY_PATH"
    exit 1
  fi
fi

if [ "$MODE" = "Single" ]; then
  echo "[*] Uploading entire file to secret 'ENV_CONTENT'..."
  gh secret set ENV_CONTENT "${COMMON_ARGS[@]}" < "$ENV_FILE"
  echo "[OK] Successfully set 'ENV_CONTENT' secret."
else
  COUNT=0
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
      continue
    fi

    if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
      KEY="${BASH_REMATCH[1]}"
      VAL="${BASH_REMATCH[2]}"

      # Skip SSH_KEY_PATH helper keys if already uploaded
      if [[ "$KEY" == "SSH_KEY_PATH" || "$KEY" == "SSH_KEY_FILE" ]]; then
        continue
      fi
      # If we already uploaded SSH_KEY from file, skip redundant assignment
      if [[ "$KEY" == "SSH_KEY" && -n "$KEY_PATH" ]]; then
        continue
      fi

      VAL=$(echo "$VAL" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

      echo "  -> Setting secret: $KEY"
      gh secret set "$KEY" "${COMMON_ARGS[@]}" --body "$VAL"
      COUNT=$((COUNT + 1))
    fi
  done < "$ENV_FILE"

  echo ""
  echo "[OK] Sync complete! Uploaded secrets to GitHub."
fi
