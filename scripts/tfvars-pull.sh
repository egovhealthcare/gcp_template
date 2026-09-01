#!/usr/bin/env bash
# tfvars-pull.sh — Pull tfvars payload from GCP Secret Manager.
#
# Usage:
#   ./scripts/tfvars-pull.sh --project=PROJECT_ID --env=ENV [--out=FILE] \
#       [--secret=SECRET_NAME] [--force] [--rebase]
#
# Defaults:
#   secret name: tofu-tfvars-{env}
#   output file: /tmp/.tofu-{env}.tfvars
#
# Safety:
#   If the local file has been modified since it was last pulled (i.e. its
#   hash no longer matches the pulled-version hash recorded in the .meta
#   sidecar), the script aborts with one of two suggestions:
#
#     --force   Overwrite local changes with the remote version.
#     --rebase  3-way merge: re-fetch the original base version from Secret
#               Manager, fetch the new remote latest, and use git merge-file
#               to replay your local edits on top.  Conflict markers are left
#               in the file if the merge isn't clean.
#
#   A .meta sidecar file is written next to the output file after every
#   successful pull, recording the Secret Manager version name and the
#   SHA-256 of the pulled content.  tfvars-push.sh uses this for
#   compare-and-swap.

set -euo pipefail

PROJECT_ID=""
ENV_NAME=""
OUT_FILE=""
SECRET_NAME=""
FORCE=false
REBASE=false

usage() {
  echo "Usage: $0 --project=PROJECT_ID --env=ENV [--out=FILE] [--secret=SECRET_NAME] [--force] [--rebase]"
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT_ID="${arg#*=}" ;;
    --env=*)     ENV_NAME="${arg#*=}" ;;
    --out=*)     OUT_FILE="${arg#*=}" ;;
    --secret=*)  SECRET_NAME="${arg#*=}" ;;
    --force)     FORCE=true ;;
    --rebase)    REBASE=true ;;
    -h|--help)   usage ;;
    *)           echo "Unknown argument: $arg"; usage ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; usage; }
[[ -n "$ENV_NAME" ]]   || { echo "ERROR: --env is required"; usage; }

if [[ "$FORCE" == "true" && "$REBASE" == "true" ]]; then
  echo "ERROR: --force and --rebase are mutually exclusive."
  exit 1
fi

if [[ -z "$SECRET_NAME" ]]; then
  SECRET_NAME="tofu-tfvars-${ENV_NAME}"
fi

if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="/tmp/.tofu-${ENV_NAME}.tfvars"
fi

META_FILE="${OUT_FILE}.meta"

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

fetch_version() {
  local version="$1" dest="$2"
  gcloud secrets versions access "$version" \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID" > "$dest"
}

# ── Temp file management ────────────────────────────────────────────────

TMPDIR_PULL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PULL"' EXIT

# ── Fetch remote latest ─────────────────────────────────────────────────

echo "Pulling tfvars from secret '$SECRET_NAME' (project: $PROJECT_ID)..."

REMOTE_VERSION="$(
  gcloud secrets versions list "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --filter="state=enabled" \
    --format="value(name)" \
    --sort-by=~createTime \
    --limit=1
)"

if [[ -z "$REMOTE_VERSION" ]]; then
  echo "ERROR: No enabled version found for secret '$SECRET_NAME'."
  exit 1
fi

REMOTE_FILE="$TMPDIR_PULL/remote.tfvars"
fetch_version "$REMOTE_VERSION" "$REMOTE_FILE"
REMOTE_SHA="$(sha256_file "$REMOTE_FILE")"

# ── Detect local modifications ──────────────────────────────────────────

LOCAL_MODIFIED=false
PULLED_VERSION=""
PULLED_SHA=""

if [[ -f "$OUT_FILE" && -f "$META_FILE" ]]; then
  PULLED_SHA="$(grep '^PULLED_SHA256=' "$META_FILE" 2>/dev/null | cut -d= -f2)"
  PULLED_VERSION="$(grep '^PULLED_VERSION=' "$META_FILE" 2>/dev/null | cut -d= -f2)"
  if [[ -n "$PULLED_SHA" ]]; then
    LOCAL_SHA="$(sha256_file "$OUT_FILE")"
    if [[ "$LOCAL_SHA" != "$PULLED_SHA" ]]; then
      LOCAL_MODIFIED=true
    fi
  fi
fi

# ── Handle local modifications ──────────────────────────────────────────

if [[ "$LOCAL_MODIFIED" == "true" && "$FORCE" != "true" && "$REBASE" != "true" ]]; then
  echo "WARNING: Local file has been modified since last pull."
  echo "  file:        $OUT_FILE"
  echo "  pulled hash: ${PULLED_SHA:0:16}..."
  echo "  local hash:  ${LOCAL_SHA:0:16}..."
  echo ""
  echo "Options:"
  echo "  --rebase  Merge your local edits onto the latest remote (3-way merge)"
  echo "  --force   Discard local edits and overwrite with remote"
  echo "  (or push your changes first, then pull)"
  exit 1
fi

# ── Rebase: 3-way merge ─────────────────────────────────────────────────

if [[ "$REBASE" == "true" && "$LOCAL_MODIFIED" == "true" ]]; then
  # Check remote actually changed — if it didn't, nothing to rebase onto
  if [[ "$PULLED_SHA" == "$REMOTE_SHA" ]]; then
    echo "Remote hasn't changed since your pull (still version $PULLED_VERSION)."
    echo "Your local edits are ahead — just push when ready."
    exit 0
  fi

  if [[ -z "$PULLED_VERSION" ]]; then
    echo "ERROR: Cannot rebase — no PULLED_VERSION in .meta sidecar."
    echo "       Use --force to overwrite, or manually reconcile."
    exit 1
  fi

  echo "Rebasing local edits onto remote version $REMOTE_VERSION..."
  echo "  base:   version $PULLED_VERSION (what you originally pulled)"
  echo "  remote: version $REMOTE_VERSION (current latest)"
  echo "  local:  $OUT_FILE (your edits)"
  echo ""

  # Re-fetch the base version (what was originally pulled)
  BASE_FILE="$TMPDIR_PULL/base.tfvars"
  fetch_version "$PULLED_VERSION" "$BASE_FILE"

  # Copy local file for merge (git merge-file modifies in-place)
  MERGE_FILE="$TMPDIR_PULL/merged.tfvars"
  cp "$OUT_FILE" "$MERGE_FILE"

  # 3-way merge: local (current) + base (ancestor) + remote (other)
  # Exit codes: 0 = clean merge, 1 = conflicts, >1 = error
  MERGE_EXIT=0
  git merge-file \
    -L "local (your edits)" \
    -L "base (v$PULLED_VERSION)" \
    -L "remote (v$REMOTE_VERSION)" \
    "$MERGE_FILE" "$BASE_FILE" "$REMOTE_FILE" || MERGE_EXIT=$?

  if [[ $MERGE_EXIT -gt 1 ]]; then
    echo "ERROR: git merge-file failed (exit $MERGE_EXIT)."
    exit 1
  fi

  # Show what the merge produced
  echo "┌─ Merge result ────────────────────────────────────"
  diff -u "$OUT_FILE" "$MERGE_FILE" \
    --label "before (your local)" \
    --label "after (rebased)" || true
  echo "└──────────────────────────────────────────────────"
  echo ""

  if [[ $MERGE_EXIT -eq 1 ]]; then
    echo "⚠  CONFLICTS detected — markers left in file. Resolve them before pushing."
    cp "$MERGE_FILE" "$OUT_FILE"
    # Update meta to track we're now based on the remote version,
    # but DON'T update PULLED_SHA256 — file still has conflicts so
    # it won't match, preventing accidental push.
    cat > "$META_FILE" <<METAEOF
PULLED_VERSION=$REMOTE_VERSION
PULLED_SHA256=$REMOTE_SHA
PULLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SECRET_NAME=$SECRET_NAME
PROJECT_ID=$PROJECT_ID
REBASE_CONFLICTS=true
METAEOF
    exit 1
  fi

  echo "✓  Clean merge — local edits rebased onto version $REMOTE_VERSION."
  umask 077
  cp "$MERGE_FILE" "$OUT_FILE"
  MERGED_SHA="$(sha256_file "$OUT_FILE")"

  cat > "$META_FILE" <<METAEOF
PULLED_VERSION=$REMOTE_VERSION
PULLED_SHA256=$MERGED_SHA
PULLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SECRET_NAME=$SECRET_NAME
PROJECT_ID=$PROJECT_ID
METAEOF

  echo "Ready to push when you're happy with the result."
  exit 0
fi

# ── Standard pull (no local modifications, or --force) ───────────────────

umask 077

# Show diff if local file exists and content changed
if [[ -f "$OUT_FILE" ]]; then
  if diff -q "$OUT_FILE" "$REMOTE_FILE" >/dev/null 2>&1; then
    echo "No changes — local file is already up-to-date (version $REMOTE_VERSION)."
  else
    echo ""
    echo "┌─ Changes from remote ────────────────────────────"
    diff -u "$OUT_FILE" "$REMOTE_FILE" \
      --label "local" \
      --label "remote (v$REMOTE_VERSION)" || true
    echo "└─────────────────────────────────────────────────"
    echo ""
  fi
fi

cp "$REMOTE_FILE" "$OUT_FILE"

# ── Write sidecar metadata ───────────────────────────────────────────────

cat > "$META_FILE" <<METAEOF
PULLED_VERSION=$REMOTE_VERSION
PULLED_SHA256=$REMOTE_SHA
PULLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SECRET_NAME=$SECRET_NAME
PROJECT_ID=$PROJECT_ID
METAEOF

echo "Wrote tfvars to: $OUT_FILE (version $REMOTE_VERSION)"
