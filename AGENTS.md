# Project Guidelines

## Overview

This repository contains GCP infrastructure-as-code for [CARE](README.md), built with OpenTofu and Helm on Google Kubernetes Engine (GKE).

## Architecture

Modules must be applied in the following order:

| Order | Module | Purpose |
|-------|--------|---------|
| 1 | `pre-infra/` | Project bootstrap: API enablement, optional DNS zone |
| 2 | `infra/` | VPC, GKE, Cloud SQL, GCS buckets, Cloud Armor, GitHub WIF |
| 3 | `KMS/` | Key ring and encryption keys |
| 4 | `deploy/` | Kubernetes namespace, secrets, Helm releases |

The `deploy/` module reads remote state from `infra` (prefix `infra`) and `KMS` (prefix `keys`) via `terraform_remote_state` data sources in `deploy/init.tf`.

## Build and Deploy

Each module directory contains a Makefile with the following targets:

| Target | Description |
|--------|-------------|
| `make init` | Initialize OpenTofu with GCS backend |
| `make pull-tfvars` | Pull tfvars from Secret Manager |
| `make plan` | Generate an execution plan |
| `make deploy` | Apply infrastructure changes |
| `make destroy` | Tear down resources |
| `make lint` | Format files recursively |
| `make push-tfvars` | Push local tfvars to Secret Manager |

### Required Environment Variables

Set the following before running any target:

- `PROJECT_ID` (or `TF_VAR_project_id`)
- `ENV_NAME` (or `TF_VAR_environment` / `TF_VAR_env_name`)
- `BACKEND_BUCKET`

### State Backend Prefixes

| Module | Prefix |
|--------|--------|
| `pre-infra/` | `pre-infra` |
| `infra/` | `infra` |
| `KMS/` | `keys` |
| `deploy/` | `deploy-backend` |

> The `deploy/` module runs `tofu plan` with `-lock=false`. All other modules use normal locking.

## Configuration

All configuration is driven by tfvars files. See [environments/sample.tfvars](environments/sample.tfvars) for the complete variable shape.

- Real tfvars are stored in Secret Manager under the name `tofu-tfvars-<env>`.
- The `make pull-tfvars` target retrieves them to `../environments/<env>.tfvars`.
- Real tfvars must never be committed to the repository.

## Conventions

### Naming

Resource names follow the pattern `{org}-{app}-{environment}` with resource-specific suffixes. Any derived name can be overridden using the `coalesce(var.override, derived_default)` pattern.

### Shared Variables

The root `variables.tf` is symlinked into each module directory. Do not create separate copies. All variables, including deploy-specific ones (`helm_config`, `additional_secrets`, `additional_config_map_data`, `enable_legacy_ingress`), are defined in this single file.

### Naming Overrides

The following optional variables override auto-derived resource names. All default to `null`:

`cluster_name`, `namespace_name`, `vpc_network_name`, `database_subnet_name`, `gke_subnet_name`, `pods_range_name`, `services_range_name`, `gateway_ip_name`, `legacy_ingress_ip_name`, `legacy_fe_ip_name`, `flow_logs_bucket`, `cloudsql_private_ip_name`, `nat_ip_address_name`

### Feature Flags

Boolean variables control optional infrastructure with `count` or `for_each`:

| Flag | Controls |
|------|----------|
| `enable_dicom` | DICOM stack (bucket, database, dcm4chee chart) |
| `enable_cloud_armor` | Cloud Armor security policies |
| `enable_github_wif` | GitHub Actions Workload Identity Federation |
| `enable_legacy_ingress` | Legacy GCE Ingress resources |
| `enable_dns_zone` | Cloud DNS managed zone |

### Provider Versions

All modules pin: `google`/`google-beta` `~> 6.33`, `random ~> 3.7`, OpenTofu `~> 1.11`.

The `deploy/` module additionally requires: `kubernetes ~> 2.0`, `helm ~> 2.0`, `tls ~> 4.0`, `local ~> 2.0`.

### Helm Value Injection

Terraform generates Helm values in `deploy/helm-values.tf` as YAML files under `deploy/generated_values/`. These are merged with `common_helm_values` (defined in `deploy/locals.tf`) and passed to `helm_release` resources in `deploy/helm.tf`.

Local charts: `gateway`, `redis`, `metabase`, `care_be`, `care_fe`, `dcm4chee`.

Additionally, `cert-manager` is installed from the Jetstack Helm repository as a dependency for TLS and Gateway API integration.

### Helm Charts

Charts are located under `helm_charts/`. Refer to [.github/instructions/helm.instructions.md](.github/instructions/helm.instructions.md) for detailed conventions. All charts share an identical `_helpers.tpl` pattern for naming, labels, and service account helpers.

## Infrastructure Components

| Component | Description |
|-----------|-------------|
| **GKE** | Regional cluster with Gateway API, Workload Identity (`terraform-google-modules/kubernetes-engine/google` ~> 36.3) |
| **Cloud SQL** | Two PostgreSQL 17 Enterprise instances (primary + Metabase), private IP, optional read replicas |
| **GCS Buckets** | Three CMEK-encrypted buckets (patient, facility, DICOM) with HMAC access |
| **Cloud Armor** | Regional security policy with OWASP rules and geo-blocking |
| **Jumphost** | Debian 13 VM with OpenTofu pre-installed (`infra/jumphost.tf`) |
| **GitHub WIF** | Workload Identity Federation for GitHub Actions CI/CD |

## Pitfalls

- Module apply order is strict. Applying out of order will fail.
- Never commit real tfvars files. Store them in Secret Manager.
- Ensure correct value types in tfvars: numbers as numbers, booleans as booleans.
- The `variables.tf` files in module directories are symlinks. Edit only the root copy.
- The `deploy/` module authenticates via `data.google_client_config` access token. Valid GCP credentials are required.
- To add new secrets, update `local.secret_data` in `deploy/locals.tf`. The `kubernetes_secret` in `deploy/secrets.tf` reads from that map automatically.
- `additional_config_map_data` injects entries into the backend ConfigMap. `additional_secrets` injects entries into the Kubernetes Secret.
