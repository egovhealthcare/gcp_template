#!/usr/bin/env bash
# tfvars-push.sh — Push tfvars payload as a new Secret Manager version.
#
# Usage:
#   ./scripts/tfvars-push.sh --project=PROJECT_ID --env=ENV --file=PATH [--secret=SECRET_NAME]
#
# Defaults:
#   secret name: tofu-tfvars-{env}

set -euo pipefail

PROJECT_ID=""
ENV_NAME=""
TFVARS_FILE=""
SECRET_NAME=""

usage() {
  echo "Usage: $0 --project=PROJECT_ID --env=ENV --file=PATH [--secret=SECRET_NAME]"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV_NAME="${arg#*=}" ;;
    --file=*)    TFVARS_FILE="${arg#*=}" ;;
    --secret=*)  SECRET_NAME="${arg#*=}" ;;
    -h|--help)   usage ;;
    *)           echo "Unknown argument: $arg"; usage ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; usage; }
[[ -n "$ENV_NAME" ]]   || { echo "ERROR: --env is required"; usage; }
[[ -n "$TFVARS_FILE" ]] || { echo "ERROR: --file is required"; usage; }
[[ -f "$TFVARS_FILE" ]] || { echo "ERROR: File not found: $TFVARS_FILE"; exit 1; }

if [[ -z "$SECRET_NAME" ]]; then
  SECRET_NAME="tofu-tfvars-${ENV_NAME}"
fi

echo "Checking tfvars formatting..."
tofu fmt -check "$TFVARS_FILE" >/dev/null

if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists. Adding a new version..."
else
  echo "Creating secret '$SECRET_NAME'..."
  gcloud secrets create "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --replication-policy=automatic
fi

echo "Uploading tfvars..."
gcloud secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file="$TFVARS_FILE" >/dev/null

LOCAL_SHA="$(shasum -a 256 "$TFVARS_FILE" | awk '{print $1}')"
REMOTE_SHA="$(
  gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID" | shasum -a 256 | awk '{print $1}'
)"

if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  echo "ERROR: Uploaded tfvars readback hash mismatch."
  exit 1
fi

echo "OK: tfvars uploaded and verified for secret '$SECRET_NAME'."

