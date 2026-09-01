#!/usr/bin/env bash
# tfvars-push.sh — Push tfvars payload as a new Secret Manager version.
#
# Usage:
#   ./scripts/tfvars-push.sh --project=PROJECT_ID --env=ENV --file=PATH \
#       [--secret=SECRET_NAME] [--force] [--yes]
#
# Defaults:
#   secret name: tofu-tfvars-{env}
#
# Safety:
#   1. project_id inside the file must match --project (prevents cross-env pushes).
#   2. Compare-and-swap: the remote latest version must match the version
#      recorded in the .meta sidecar written by tfvars-pull.sh.  If someone
#      else pushed since your last pull, the script aborts unless --force.
#   3. Shows a diff of local changes vs. remote latest before uploading.
#   4. Prompts for confirmation unless --yes is given.

set -euo pipefail

PROJECT_ID=""
ENV_NAME=""
TFVARS_FILE=""
SECRET_NAME=""
FORCE=false
YES=false

MAX_VERSIONS=10

usage() {
  echo "Usage: $0 --project=PROJECT_ID --env=ENV --file=PATH [--secret=SECRET_NAME] [--force] [--yes]"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV_NAME="${arg#*=}" ;;
    --file=*)    TFVARS_FILE="${arg#*=}" ;;
    --secret=*)  SECRET_NAME="${arg#*=}" ;;
    --force)     FORCE=true ;;
    --yes|-y)    YES=true ;;
    -h|--help)   usage ;;
    *)           echo "Unknown argument: $arg"; usage ;;
  esac
done

[[ -n "$PROJECT_ID" ]]  || { echo "ERROR: --project is required"; usage; }
[[ -n "$ENV_NAME" ]]    || { echo "ERROR: --env is required"; usage; }
[[ -n "$TFVARS_FILE" ]] || { echo "ERROR: --file is required"; usage; }
[[ -f "$TFVARS_FILE" ]] || { echo "ERROR: File not found: $TFVARS_FILE"; exit 1; }

META_FILE="${TFVARS_FILE}.meta"

# ── Helpers ──────────────────────────────────────────────────────────────

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    echo "ERROR: No SHA-256 tool found." >&2; exit 1
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{print $NF}'
  else
    echo "ERROR: No SHA-256 tool found." >&2; exit 1
  fi
}

# ── Safety check: project_id alignment ───────────────────────────────────

TFVARS_PROJECT_ID="$(
  grep -E '^[[:space:]]*project_id[[:space:]]*=' "$TFVARS_FILE" \
    | head -n1 \
    | sed -E 's/^[[:space:]]*project_id[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
)"

if [[ -z "$TFVARS_PROJECT_ID" ]]; then
  echo "ERROR: Could not find 'project_id = \"...\"' in $TFVARS_FILE."
  echo "       Refusing to push without verifying project alignment."
  exit 1
fi

if [[ "$TFVARS_PROJECT_ID" != "$PROJECT_ID" ]]; then
  echo "ERROR: project_id mismatch — refusing to push."
  echo "       --project argument : $PROJECT_ID"
  echo "       project_id in file : $TFVARS_PROJECT_ID  ($TFVARS_FILE)"
  exit 1
fi

# ── Extract region ───────────────────────────────────────────────────────

TFVARS_REGION="$(
  grep -E '^[[:space:]]*region[[:space:]]*=' "$TFVARS_FILE" \
    | head -n1 \
    | sed -E 's/^[[:space:]]*region[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
)"

if [[ -z "$TFVARS_REGION" ]]; then
  echo "ERROR: Could not find 'region = \"...\"' in $TFVARS_FILE."
  exit 1
fi

if [[ -z "$SECRET_NAME" ]]; then
  SECRET_NAME="tofu-tfvars-${ENV_NAME}"
fi

# ── Format ───────────────────────────────────────────────────────────────

echo "Formatting tfvars..."
tofu fmt "$TFVARS_FILE" >/dev/null
if ! tofu fmt -check "$TFVARS_FILE" >/dev/null 2>&1; then
  echo "ERROR: '$TFVARS_FILE' is not properly formatted after 'tofu fmt'."
  exit 1
fi

# ── Ensure secret exists ────────────────────────────────────────────────

SECRET_EXISTS=true
if ! gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
  SECRET_EXISTS=false
fi

# ── Compare-and-swap: verify remote hasn't changed since pull ────────────

if [[ "$SECRET_EXISTS" == "true" ]]; then
  REMOTE_VERSION="$(
    gcloud secrets versions list "$SECRET_NAME" \
      --project="$PROJECT_ID" \
      --filter="state=enabled" \
      --format="value(name)" \
      --sort-by=~createTime \
      --limit=1
  )"

  # Fetch remote content for diff
  TMPREMOTE="$(mktemp)"
  trap 'rm -f "$TMPREMOTE"' EXIT

  gcloud secrets versions access "$REMOTE_VERSION" \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID" > "$TMPREMOTE"

  REMOTE_SHA="$(sha256_file "$TMPREMOTE")"

  # Check if meta sidecar exists and versions match
  if [[ -f "$META_FILE" && "$FORCE" != "true" ]]; then
    PULLED_VERSION="$(grep '^PULLED_VERSION=' "$META_FILE" 2>/dev/null | cut -d= -f2)"

    if [[ -n "$PULLED_VERSION" && "$PULLED_VERSION" != "$REMOTE_VERSION" ]]; then
      echo "ERROR: Remote secret has changed since your last pull!"
      echo "  You pulled version : $PULLED_VERSION"
      echo "  Remote latest      : $REMOTE_VERSION"
      echo ""
      echo "Options:"
      echo "  make rebase-tfvars   Merge your local edits onto the new remote"
      echo "  FORCE_PUSH=true      Overwrite remote with your local version"
      exit 1
    fi
  elif [[ ! -f "$META_FILE" && "$FORCE" != "true" ]]; then
    echo "WARNING: No .meta sidecar found — cannot verify you pulled before editing."
    echo "  This file may be stale. Run 'make pull-tfvars' first, or re-run with --force."
    exit 1
  fi

  # Show diff of what will change
  LOCAL_SHA="$(sha256_file "$TFVARS_FILE")"
  if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
    echo "No changes to push — local file matches remote version $REMOTE_VERSION."
    exit 0
  fi

  echo ""
  echo "┌─ Changes to push (remote v$REMOTE_VERSION → local) ─────────"
  diff -u "$TMPREMOTE" "$TFVARS_FILE" \
    --label "remote (v$REMOTE_VERSION)" \
    --label "local" || true
  echo "└─────────────────────────────────────────────────"
  echo ""

else
  echo "Secret '$SECRET_NAME' does not exist. Will create it."
  echo ""
fi

# ── Confirmation prompt ──────────────────────────────────────────────────

if [[ "$YES" != "true" ]]; then
  printf "Push tfvars to secret '%s' in project '%s'? [y/N] " "$SECRET_NAME" "$PROJECT_ID"
  read -r CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Create secret if needed ─────────────────────────────────────────────

if [[ "$SECRET_EXISTS" != "true" ]]; then
  echo "Creating secret '$SECRET_NAME' (project: $PROJECT_ID, location: $TFVARS_REGION)..."
  gcloud secrets create "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --replication-policy=user-managed \
    --locations="$TFVARS_REGION"
fi

# ── Upload ───────────────────────────────────────────────────────────────

echo "Uploading tfvars to project '$PROJECT_ID'..."
gcloud secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file="$TFVARS_FILE" >/dev/null

# ── Verify readback ─────────────────────────────────────────────────────

LOCAL_SHA="$(sha256_file "$TFVARS_FILE")"
READBACK_SHA="$(
  gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID" | sha256_stdin
)"

if [[ "$LOCAL_SHA" != "$READBACK_SHA" ]]; then
  echo "ERROR: Uploaded tfvars readback hash mismatch!"
  exit 1
fi

# ── Update sidecar to reflect new state ──────────────────────────────────

NEW_VERSION="$(
  gcloud secrets versions list "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --filter="state=enabled" \
    --format="value(name)" \
    --sort-by=~createTime \
    --limit=1
)"

cat > "$META_FILE" <<METAEOF
PULLED_VERSION=$NEW_VERSION
PULLED_SHA256=$LOCAL_SHA
PULLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SECRET_NAME=$SECRET_NAME
PROJECT_ID=$PROJECT_ID
METAEOF

# ── Prune old versions ──────────────────────────────────────────────────

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

echo "OK: tfvars pushed as version $NEW_VERSION for secret '$SECRET_NAME' (project: $PROJECT_ID)."
