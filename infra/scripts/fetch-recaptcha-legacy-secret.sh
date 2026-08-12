#!/usr/bin/env bash
# Fetches the legacy reCAPTCHA secret key for an Enterprise key.
#
# The hashicorp/google provider does not expose the legacy secret key and there is no
# gcloud subcommand for it, so this calls the REST method directly. The response is
# already the flat {"legacySecretKey": "..."} object that `data "external"` expects.
#
# Input (stdin, JSON): { "key_name": "projects/P/keys/K", "access_token": "ya29..." }
set -euo pipefail

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "fetch-recaptcha-legacy-secret.sh: '$cmd' is required but not installed" >&2
    exit 1
  fi
done

query="$(cat)"
key_name="$(jq -r '.key_name' <<<"$query")"
access_token="$(jq -r '.access_token' <<<"$query")"

if [[ -z "$key_name" || "$key_name" == "null" ]]; then
  echo "fetch-recaptcha-legacy-secret.sh: key_name is required" >&2
  exit 1
fi

if [[ -z "$access_token" || "$access_token" == "null" ]]; then
  echo "fetch-recaptcha-legacy-secret.sh: access_token is required (is the google provider authenticated?)" >&2
  exit 1
fi

if ! response="$(curl -sS --fail-with-body \
  -H "Authorization: Bearer ${access_token}" \
  "https://recaptchaenterprise.googleapis.com/v1/${key_name}:retrieveLegacySecretKey")"; then
  echo "fetch-recaptcha-legacy-secret.sh: request failed for ${key_name}: ${response:-no response}" >&2
  exit 1
fi

if ! jq -e 'has("legacySecretKey")' >/dev/null 2>&1 <<<"$response"; then
  echo "fetch-recaptcha-legacy-secret.sh: unexpected response for ${key_name}: ${response}" >&2
  exit 1
fi

jq -c '{legacySecretKey: .legacySecretKey}' <<<"$response"
