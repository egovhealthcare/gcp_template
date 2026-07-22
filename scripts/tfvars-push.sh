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

MAX_VERSIONS=10

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

# Safety check: Project ID
TFVARS_PROJECT_ID="$(
  grep -E '^[[:space:]]*project_id[[:space:]]*=' "$TFVARS_FILE" \
    | head -n1 \
    | sed -E 's/^[[:space:]]*project_id[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
)"

if [[ -z "$TFVARS_PROJECT_ID" ]]; then
  echo "ERROR: Could not find a 'project_id = \"...\"' entry in $TFVARS_FILE."
  echo "       Refusing to push without verifying project alignment."
  exit 1
fi

if [[ "$TFVARS_PROJECT_ID" != "$PROJECT_ID" ]]; then
  echo "ERROR: project_id mismatch — refusing to push."
  echo "       --project argument : $PROJECT_ID"
  echo "       project_id in file : $TFVARS_PROJECT_ID  ($TFVARS_FILE)"
  echo "       This guard prevents pushing tfvars from one project into another."
  exit 1
fi

if [[ -z "$SECRET_NAME" ]]; then
  SECRET_NAME="tofu-tfvars-${ENV_NAME}"
fi

echo "Formatting tfvars..."
tofu fmt "$TFVARS_FILE" >/dev/null
echo "Verifying tfvars formatting..."
if ! tofu fmt -check "$TFVARS_FILE" >/dev/null 2>&1; then
  echo "ERROR: '$TFVARS_FILE' is still not properly formatted after 'tofu fmt'. Please fix manually."
  exit 1
fi

if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Secret '$SECRET_NAME' exists (project: $PROJECT_ID). Adding a new version..."
else
  echo "Creating secret '$SECRET_NAME' (project: $PROJECT_ID)..."
  gcloud secrets create "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --replication-policy=automatic
fi

echo "Uploading tfvars to project '$PROJECT_ID'..."
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

# Prune old versions — keep only the MAX_VERSIONS most recent
echo "Pruning old versions (keeping $MAX_VERSIONS most recent)..."
gcloud secrets versions list "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --filter="state=enabled" \
  --format="value(name)" \
  --sort-by=~createTime \
  | tail -n +$((MAX_VERSIONS + 1)) \
  | while read -r version; do
      [[ -z "$version" ]] && continue
      echo "  Destroying version $version..."
      gcloud secrets versions destroy "$version" \
        --secret="$SECRET_NAME" \
        --project="$PROJECT_ID" --quiet
    done

echo "OK: tfvars uploaded and verified for secret '$SECRET_NAME' (project: $PROJECT_ID)."
