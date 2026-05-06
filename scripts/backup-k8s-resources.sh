#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 -n <namespace> [-o <output-dir>] [-c <context>]"
  echo
  echo "  -n  Kubernetes namespace (required)"
  echo "  -o  Output directory (default: ./k8s-backup-<namespace>-<timestamp>)"
  echo "  -c  kubectl context to use"
  exit 1
}

NAMESPACE=""
OUTPUT_DIR=""
CONTEXT=""

while getopts "n:o:c:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    c) CONTEXT="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$NAMESPACE" ]]; then
  echo "Error: namespace is required"
  usage
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="${OUTPUT_DIR:-./k8s-backup-${NAMESPACE}-${TIMESTAMP}}"

KUBECTL="kubectl"
if [[ -n "$CONTEXT" ]]; then
  KUBECTL="kubectl --context=$CONTEXT"
fi

SECRETS_DIR="${OUTPUT_DIR}/secrets"
CONFIGMAPS_DIR="${OUTPUT_DIR}/configmaps"
mkdir -p "$SECRETS_DIR" "$CONFIGMAPS_DIR"

echo "Backing up namespace: $NAMESPACE"
echo "Output directory: $OUTPUT_DIR"

# Backup secrets
echo "--- Backing up Secrets ---"
SECRETS=$($KUBECTL get secrets -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
for secret in $SECRETS; do
  echo "  Secret: $secret"
  $KUBECTL get secret "$secret" -n "$NAMESPACE" -o yaml > "${SECRETS_DIR}/${secret}.yaml"
done

# Backup configmaps
echo "--- Backing up ConfigMaps ---"
CONFIGMAPS=$($KUBECTL get configmaps -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
for cm in $CONFIGMAPS; do
  echo "  ConfigMap: $cm"
  $KUBECTL get configmap "$cm" -n "$NAMESPACE" -o yaml > "${CONFIGMAPS_DIR}/${cm}.yaml"
done

SECRET_COUNT=$(echo "$SECRETS" | wc -w | tr -d ' ')
CM_COUNT=$(echo "$CONFIGMAPS" | wc -w | tr -d ' ')

echo
echo "Backup complete: ${SECRET_COUNT} secrets, ${CM_COUNT} configmaps"
echo "Location: $OUTPUT_DIR"
