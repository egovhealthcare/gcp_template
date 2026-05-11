# CARE GCP OpenTofu Infrastructure

Infrastructure-as-code for CARE on GCP using OpenTofu (Terraform-compatible).

## Repository Layout

- `pre-infra/` : Project-level bootstrap (API enablement, optional DNS zone)
- `infra/` : Core platform (VPC, GKE, Cloud SQL, buckets, Cloud Armor, GitHub WIF)
- `KMS/` : KMS key ring and crypto keys
- `deploy/` : Kubernetes namespace, secrets, Helm releases
- `helm_charts/` : Application Helm charts (`care_be`, `care_fe`, `gateway`, `metabase`, `redis`, `dcm4chee`)
- `environments/` : Safe sample tfvars and environment variable documentation
- `scripts/` : helper scripts for tfvars secret sync and maintenance

## Deployment Order

1. `pre-infra`
2. `infra`
3. `KMS`
4. `deploy`

`deploy/` depends on remote state outputs from `infra/` and `KMS/`.

## Configuration Model

- Runtime config is tfvars-based.
- Each module reads `../environments/<env>.tfvars` (pulled from Secret Manager by Makefile targets).
- Secret name pattern: `tofu-tfvars-<env>`.
- Canonical safe template: `environments/sample.tfvars`.

## Required Inputs

Environment variables used by all module Makefiles:

- `PROJECT_ID` (or `TF_VAR_project_id`)
- `ENV_NAME` (or `TF_VAR_environment` / `TF_VAR_env_name`)
- `BACKEND_BUCKET`

Initial setup (run once per terminal session):

```bash
export BACKEND_BUCKET="iac-tofu-egov-hmis"
export PROJECT_ID="e-govt-foundation"
export ENV_NAME="prod"
```

## Common Commands

From each module directory (`pre-infra/`, `infra/`, `KMS/`, `deploy/`):

```bash
make init BACKEND_BUCKET=<state-bucket>
make pull-tfvars PROJECT_ID=<gcp-project> ENV_NAME=<env>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>
make deploy PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>
```

Push local tfvars to Secret Manager:

```bash
make push-tfvars PROJECT_ID=<gcp-project> ENV_NAME=<env>
```

By default this pushes `../environments/<env>.tfvars`. Override with `LOCAL_TFVARS_FILE=<path>` if needed.

## Security Notes

- Do not commit real environment tfvars/json payloads.
- Keep only sanitized samples in the repo.
- Store real env payloads in Secret Manager.
