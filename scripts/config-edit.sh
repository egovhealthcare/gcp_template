#!/usr/bin/env bash
# config-edit.sh — Edit the environment config stored in GCP Secret Manager.
# Opens the JSON in your $EDITOR, validates it, and uploads as a new secret version.
#
# Usage:
#   ./scripts/config-edit.sh --project=PROJECT_ID --env=ENV [--vscode|--kiro]
#
# Example:
#   ./scripts/config-edit.sh --project=devops-care --env=prod
#   ./scripts/config-edit.sh --project=devops-care --env=prod --vscode
#   ./scripts/config-edit.sh --project=devops-care --env=prod --kiro

set -euo pipefail

PROJECT_ID=""
ENV=""
USE_VSCODE=false
USE_KIRO=false

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV="${arg#*=}" ;;
    --vscode)    USE_VSCODE=true ;;
    --kiro)      USE_KIRO=true ;;
    -h|--help)
      echo "Usage: $0 --project=PROJECT_ID --env=ENV [--vscode|--kiro]"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; exit 1; }
[[ -n "$ENV" ]]        || { echo "ERROR: --env is required"; exit 1; }

SECRET_NAME="tofu-env-${ENV}"
TMPFILE=$(mktemp /tmp/.care-config-edit-XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

# Fetch current config
echo "Fetching current config for '$SECRET_NAME'..."
gcloud secrets versions access latest \
  --secret="$SECRET_NAME" \
  --project="$PROJECT_ID" | jq . > "$TMPFILE"
chmod 600 "$TMPFILE"

# Capture checksum before editing
BEFORE=$(shasum -a 256 "$TMPFILE" | awk '{print $1}')

# Open in editor
if [[ "$USE_VSCODE" == "true" ]]; then
  if ! command -v code >/dev/null 2>&1; then
    echo "ERROR: VS Code CLI 'code' not found in PATH."
    echo "Install it from VS Code: Command Palette -> 'Shell Command: Install code command in PATH'."
    exit 1
  fi
  code --wait "$TMPFILE"
elif [[ "$USE_KIRO" == "true" ]]; then
  if ! command -v kiro >/dev/null 2>&1; then
    echo "ERROR: Kiro CLI 'kiro' not found in PATH."
    echo "Install it from Kiro: Command Palette -> 'Shell Command: Install kiro command in PATH'."
    exit 1
  fi
  kiro --wait "$TMPFILE"
else
  ${EDITOR:-vim} "$TMPFILE"
fi

# Check if anything changed
AFTER=$(shasum -a 256 "$TMPFILE" | awk '{print $1}')
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "No changes detected. Aborting."
  exit 0
fi

# Validate JSON
if ! jq empty "$TMPFILE" 2>/dev/null; then
  echo "ERROR: Edited file is not valid JSON. Not uploading."
  echo "Your edits are saved at: $TMPFILE"
  trap - EXIT  # Don't delete the file so user can recover
  exit 1
fi

# Confirm
echo ""
echo "Changes detected. Upload new version to '$SECRET_NAME'? [y/N]"
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Upload
gcloud secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file="$TMPFILE"

echo "Done! New version uploaded to '$SECRET_NAME'."
