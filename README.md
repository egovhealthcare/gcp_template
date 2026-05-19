# CARE GCP Infrastructure

Infrastructure-as-code for the CARE application on Google Cloud Platform, using OpenTofu and Helm.

## Repository Layout

| Directory | Purpose |
|-----------|---------|
| `pre-infra/` | Project-level bootstrap (API enablement, optional DNS zone) |
| `infra/` | Core platform (VPC, GKE, Cloud SQL, GCS, Cloud Armor, GitHub WIF) |
| `KMS/` | KMS key ring and encryption keys |
| `deploy/` | Kubernetes namespace, secrets, Helm releases |
| `helm_charts/` | Application Helm charts (`care_be`, `care_fe`, `gateway`, `metabase`, `redis`, `dcm4chee`) |
| `environments/` | Sample tfvars template and variable documentation |
| `scripts/` | Helper scripts for tfvars synchronisation with Secret Manager |

## Deployment Order

Modules must be applied sequentially:

1. `pre-infra/`
2. `infra/`
3. `KMS/`
4. `deploy/`

The `deploy/` module depends on remote state outputs from both `infra/` and `KMS/`.

## Configuration

- All configuration is tfvars-based.
- Each module reads `../environments/<env>.tfvars`, pulled from Secret Manager by Makefile targets.
- Secret Manager naming convention: `tofu-tfvars-<env>`.
- The canonical template is [environments/sample.tfvars](environments/sample.tfvars).

## Required Environment Variables

Set the following before running any Makefile target:

| Variable | Description |
|----------|-------------|
| `PROJECT_ID` | GCP project ID (or `TF_VAR_project_id`) |
| `ENV_NAME` | Environment name (or `TF_VAR_environment` / `TF_VAR_env_name`) |
| `BACKEND_BUCKET` | GCS bucket for OpenTofu state |

```bash
export BACKEND_BUCKET="<your-state-bucket>"
export PROJECT_ID="<your-gcp-project-id>"
export ENV_NAME="<environment-name>"
```

## Common Commands

Run from any module directory (`pre-infra/`, `infra/`, `KMS/`, `deploy/`):

```bash
make init BACKEND_BUCKET=<state-bucket>
make pull-tfvars PROJECT_ID=<gcp-project> ENV_NAME=<env>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>
make deploy PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>
```

To push local tfvars to Secret Manager:

```bash
make push-tfvars PROJECT_ID=<gcp-project> ENV_NAME=<env>
```

Override the default file path with `LOCAL_TFVARS_FILE=<path>` if needed.

## Security

- Do not commit real environment tfvars to the repository.
- Only sanitised samples should be checked in.
- All real configuration must reside in Secret Manager.
