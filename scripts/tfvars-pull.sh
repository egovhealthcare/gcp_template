#!/usr/bin/env bash
# tfvars-pull.sh — Pull tfvars payload from GCP Secret Manager.
#
# Usage:
#   ./scripts/tfvars-pull.sh --project=PROJECT_ID --env=ENV [--out=FILE] [--secret=SECRET_NAME]
#
# Defaults:
#   secret name: tofu-tfvars-{env}
#   output file: /tmp/.tofu-{env}.tfvars

set -euo pipefail

PROJECT_ID=""
ENV_NAME=""
OUT_FILE=""
SECRET_NAME=""

usage() {
  echo "Usage: $0 --project=PROJECT_ID --env=ENV [--out=FILE] [--secret=SECRET_NAME]"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV_NAME="${arg#*=}" ;;
    --out=*)     OUT_FILE="${arg#*=}" ;;
    --secret=*)  SECRET_NAME="${arg#*=}" ;;
    -h|--help)   usage ;;
    *)           echo "Unknown argument: $arg"; usage ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; usage; }
[[ -n "$ENV_NAME" ]]   || { echo "ERROR: --env is required"; usage; }

if [[ -z "$SECRET_NAME" ]]; then
  SECRET_NAME="tofu-tfvars-${ENV_NAME}"
fi

if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="/tmp/.tofu-${ENV_NAME}.tfvars"
fi

echo "Pulling tfvars from secret '$SECRET_NAME' (project: $PROJECT_ID)..."

# Restrict file permissions before writing
umask 077
gcloud secrets versions access latest \
  --secret="$SECRET_NAME" \
  --project="$PROJECT_ID" > "$OUT_FILE"

echo "Wrote tfvars to: $OUT_FILE"
