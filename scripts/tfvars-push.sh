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

sha256_file() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $2}'
  else
    echo "ERROR: No SHA-256 tool found. Install one of: sha256sum, shasum, openssl." >&2
    exit 1
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{print $2}'
  else
    echo "ERROR: No SHA-256 tool found. Install one of: sha256sum, shasum, openssl." >&2
    exit 1
  fi
}

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

LOCAL_SHA="$(sha256_file "$TFVARS_FILE")"
REMOTE_SHA="$(
  gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID" | sha256_stdin
)"

if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  echo "ERROR: Uploaded tfvars readback hash mismatch."
  exit 1
fi

echo "OK: tfvars uploaded and verified for secret '$SECRET_NAME'."
