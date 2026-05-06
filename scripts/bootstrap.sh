#!/usr/bin/env bash
# bootstrap.sh — One-time setup: create a GCP Secret Manager secret for an environment
# and upload the initial config JSON.
#
# Usage:
#   ./scripts/bootstrap.sh --project=PROJECT_ID --env=ENV --file=path/to/config.json
#
# Example:
#   # First, copy and fill in the template:
#   cp scripts/config-template.json /tmp/my-config.json
#   vim /tmp/my-config.json
#
#   # Then bootstrap:
#   ./scripts/bootstrap.sh --project=devops-care --env=prod --file=/tmp/my-config.json
#
# Prerequisites:
#   - gcloud CLI authenticated with a principal that has roles/secretmanager.admin
#   - Secret Manager API enabled (run pre-infra first, or enable manually)
#   - jq installed (for JSON validation)

set -euo pipefail

PROJECT_ID=""
ENV=""
CONFIG_FILE=""

usage() {
  echo "Usage: $0 --project=PROJECT_ID --env=ENV --file=CONFIG_JSON"
  echo ""
  echo "  --project   GCP project ID"
  echo "  --env       Environment name (e.g. prod, staging, dev)"
  echo "  --file      Path to JSON config file to upload"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV="${arg#*=}" ;;
    --file=*)    CONFIG_FILE="${arg#*=}" ;;
    -h|--help)   usage ;;
    *)           echo "Unknown argument: $arg"; usage ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; usage; }
[[ -n "$ENV" ]]        || { echo "ERROR: --env is required"; usage; }
[[ -n "$CONFIG_FILE" ]] || { echo "ERROR: --file is required"; usage; }
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: File not found: $CONFIG_FILE"; exit 1; }

# Validate JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo "ERROR: $CONFIG_FILE is not valid JSON"
  exit 1
fi

SECRET_NAME="tofu-env-${ENV}"

echo "==> Project:  $PROJECT_ID"
echo "==> Secret:   $SECRET_NAME"
echo "==> Config:   $CONFIG_FILE"
echo ""

# Create the secret (ignore error if it already exists)
if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
  echo "Secret '$SECRET_NAME' already exists, adding new version..."
else
  echo "Creating secret '$SECRET_NAME'..."
  gcloud secrets create "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --replication-policy=automatic
fi

# Upload the config as a new secret version
echo "Uploading config..."
gcloud secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file="$CONFIG_FILE"

# Validate: read it back and compare
echo "Validating..."
READBACK=$(gcloud secrets versions access latest \
  --secret="$SECRET_NAME" \
  --project="$PROJECT_ID")

if diff <(jq -S . "$CONFIG_FILE") <(echo "$READBACK" | jq -S .) &>/dev/null; then
  echo "OK: Config uploaded and verified."
else
  echo "WARNING: Readback does not match uploaded file. Please check manually."
  exit 1
fi

echo ""
echo "Done! You can now use:"
echo "  make plan PROJECT_ID=$PROJECT_ID ENV=$ENV"
