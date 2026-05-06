#!/usr/bin/env bash
# config-view.sh — View the environment config from GCP Secret Manager.
# Sensitive values (jwks, sentry, scribe, passwords) are redacted by default.
#
# Usage:
#   ./scripts/config-view.sh --project=PROJECT_ID --env=ENV [--show-secrets]
#
# Example:
#   ./scripts/config-view.sh --project=devops-care --env=prod
#   ./scripts/config-view.sh --project=devops-care --env=prod --show-secrets

set -euo pipefail

PROJECT_ID=""
ENV=""
SHOW_SECRETS=false

for arg in "$@"; do
  case "$arg" in
    --project=*)    PROJECT_ID="${arg#*=}" ;;
    --env=*)        ENV="${arg#*=}" ;;
    --show-secrets) SHOW_SECRETS=true ;;
    -h|--help)
      echo "Usage: $0 --project=PROJECT_ID --env=ENV [--show-secrets]"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

[[ -n "$PROJECT_ID" ]] || { echo "ERROR: --project is required"; exit 1; }
[[ -n "$ENV" ]]        || { echo "ERROR: --env is required"; exit 1; }

SECRET_NAME="tofu-env-${ENV}"

CONFIG=$(gcloud secrets versions access latest \
  --secret="$SECRET_NAME" \
  --project="$PROJECT_ID")

if [[ "$SHOW_SECRETS" == "true" ]]; then
  echo "$CONFIG" | jq .
else
  echo "$CONFIG" | jq 'with_entries(
    if (.key | test("jwks|sentry|scribe|secret|password|dsn"; "i"))
    then .value = "***REDACTED***"
    else .
    end
  )'
fi
