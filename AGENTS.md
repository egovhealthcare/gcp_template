# Project Guidelines

## Overview

GCP infrastructure-as-code for [CARE](README.md) using OpenTofu (`tofu`) and Helm on GKE.

## Architecture

Apply modules in strict order:

1. `pre-infra/` — project bootstrap (API enablement, optional DNS zone)
2. `infra/` — VPC, GKE, Cloud SQL, buckets, Cloud Armor, GitHub WIF
3. `KMS/` — key ring and crypto keys
4. `deploy/` — namespace, secrets, Helm releases

`deploy/` reads remote state from `infra` (prefix `infra`) and `KMS` (prefix `keys`) via `terraform_remote_state` in `deploy/init.tf`.

## Build & Deploy

Each module directory has a Makefile with identical targets:

```sh
make init          # tofu init with GCS backend
make pull-tfvars   # pull tfvars from Secret Manager
make plan          # tofu plan using pulled tfvars
make deploy        # tofu apply
make destroy       # tofu destroy
make lint          # tofu fmt -write=true -recursive
make push-tfvars   # push local tfvars to Secret Manager
```

Required environment variables (set before running any make target):

- `PROJECT_ID` (or `TF_VAR_project_id`)
- `ENV_NAME` (or `TF_VAR_environment` / `TF_VAR_env_name`)
- `BACKEND_BUCKET`

State backend prefixes per module: `pre-infra`, `infra`, `keys`, `deploy-backend`.

> **Note:** `deploy/` plan uses `-lock=false`; all other modules lock normally.

## Configuration

- All config is tfvars-driven. See [environments/sample.tfvars](environments/sample.tfvars) for the full variable shape.
- Real tfvars are stored in Secret Manager as `tofu-tfvars-<env>`.
- Pulled at runtime to `../environments/<env>.tfvars` by `make pull-tfvars`.
- Never commit real tfvars to the repo.

## Conventions

### Naming

Resource names follow `{org}-{app}-{environment}` with resource-specific suffixes. Override any derived name via a `coalesce(var.override, derived_default)` pattern.

### Shared Variables

Root `variables.tf` is **symlinked** into each module directory — do not create separate copies. Module-specific variables go in the module's own `variables.tf` (see `deploy/variables.tf` for deploy-only variables like `helm_config`, `additional_secrets`, `enable_legacy_ingress`).

### Feature Flags

Boolean variables (`enable_dicom`, `enable_cloud_armor`, `enable_github_wif`, `enable_legacy_ingress`, `enable_dns_zone`) gate resources with `count` or `for_each`.

### Provider Versions

All modules pin: `google`/`google-beta` `~> 6.33`, `random ~> 3.7`, OpenTofu `~> 1.11`. `deploy/` additionally requires `kubernetes ~> 2.0`, `helm ~> 2.0`, `tls ~> 4.0`, `local ~> 2.0`.

### Helm Value Injection

Terraform generates Helm values in `deploy/helm-values.tf` as YAML files under `deploy/generated_values/`. These are merged with `common_helm_values` (defined in `deploy/locals.tf`) and passed to `helm_release` resources in `deploy/helm.tf`. Charts: `gateway`, `redis`, `metabase`, `care_be`, `care_fe`, `dcm4chee`.

### Helm Charts

Charts live under `helm_charts/`. See [.github/instructions/helm.instructions.md](.github/instructions/helm.instructions.md) for conventions. All charts share an identical `_helpers.tpl` pattern for naming, labels, and service account helpers.

## Pitfalls

- Module apply order is strict: `pre-infra` → `infra` → `KMS` → `deploy`.
- Do not commit real tfvars; store them in Secret Manager.
- Keep tfvars value types correct (numbers as numbers, booleans as booleans).
- `variables.tf` in module dirs are symlinks — edit the root file, not the symlink targets.
- `deploy/` Kubernetes/Helm providers authenticate via `data.google_client_config` access token — requires valid GCP credentials.
- Secrets in `deploy/locals.tf` are composed from remote state outputs; adding new secrets means updating `local.secret_data` and the corresponding `kubernetes_secret` in `deploy/secrets.tf`.
