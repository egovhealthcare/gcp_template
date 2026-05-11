# Environment tfvars Guide

This folder contains a sanitized template for environment configuration.

## Files

- `sample.tfvars` : canonical sample payload (safe placeholders only)
- `README.md` : usage and variable reference

Do not commit real environment payloads in this directory.

## Runtime Model

Real environment tfvars live in GCP Secret Manager and are pulled at runtime by module Makefiles.

- Secret name pattern: `tofu-tfvars-<env>`
- Pull script: `scripts/tfvars-pull.sh`
- Push script: `scripts/tfvars-push.sh`

## How To Use

Initial setup (run once per terminal session):

```bash
export BACKEND_BUCKET="iac-tofu-egov-hmis"
export PROJECT_ID="e-govt-foundation"
export ENV_NAME="prod"
```

1. Copy the sample:

```bash
cp environments/sample.tfvars environments/<env>.tfvars
```

2. Edit values.

3. Push to Secret Manager:

```bash
cd pre-infra
make push-tfvars PROJECT_ID=<gcp-project> ENV_NAME=<env>
```

By default this pushes `../environments/<env>.tfvars`. Override with `LOCAL_TFVARS_FILE=<path>` if needed.

4. Plan/apply module by module:

```bash
cd pre-infra
make init BACKEND_BUCKET=<state-bucket>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>

cd ../infra
make init BACKEND_BUCKET=<state-bucket>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>

cd ../KMS
make init BACKEND_BUCKET=<state-bucket>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>

cd ../deploy
make init BACKEND_BUCKET=<state-bucket>
make plan PROJECT_ID=<gcp-project> ENV_NAME=<env> BACKEND_BUCKET=<state-bucket>
```

## Variable Reference

Source of truth is root `variables.tf`.

### Core

| Variable | Type | Default | Example |
|---|---|---|---|
| `project_id` | `string` | none | `"example-project-id"` |
| `project_number` | `string` | `null` | `"123456789012"` |
| `region` | `string` | `"us-central1"` | `"asia-south1"` |
| `org` | `string` | `"ohn"` | `"example-org"` |
| `app` | `string` | none | `"example-app"` |
| `environment` | `string` | `"prod"` | `"staging"` |

### Networking and Cluster

| Variable | Type | Default | Example |
|---|---|---|---|
| `zones` | `list(string)` | `[]` | `["asia-south1-a", "asia-south1-b"]` |
| `zone` | `string` | `null` | `"asia-south1-a"` |
| `node_pools` | `any` | `[]` | list of node pool objects |
| `database_subnets` | `string` | `null` | `"10.0.21.0/24"` |
| `gke_subnets` | `string` | `null` | `"10.20.0.0/16"` |
| `gke_pods_range` | `string` | `null` | `"10.21.0.0/16"` |
| `gke_services_range` | `string` | `null` | `"10.22.0.0/20"` |
| `proxy_only_subnet_cidr` | `string` | `null` | `"10.129.0.0/23"` |
| `service_account_email` | `string` | `null` | `"iac-tofu@example-project-id.iam.gserviceaccount.com"` |
| `jumphost_ssh_keys` | `any` | `[]` | list of `{ user, key }` |

### DNS and Domains

| Variable | Type | Default | Example |
|---|---|---|---|
| `enable_dns_zone` | `bool` | `false` | `true` |
| `dns_zone_domain` | `string` | `""` | `"example.org"` |
| `web_domain_name` | `list(string)` | `[]` | `["app.example.org"]` |
| `api_domain_name` | `list(string)` | `[]` | `["api.example.org"]` |
| `metabase_domain_name` | `list(string)` | `[]` | `["metabase.example.org"]` |
| `dicom_domain_name` | `list(string)` | `[]` | `["dicom.example.org"]` |

### Database

| Variable | Type | Default | Example |
|---|---|---|---|
| `cloudsql_tier` | `string` | `null` | `"db-custom-2-3840"` |
| `cloudsql_disk_size` | `any` | `null` | `10` |
| `cloudsql_read_replica_count` | `any` | `0` | `1` |
| `cloudsql_read_replica_tier` | `string` | `null` | `"db-custom-1-3840"` |
| `metabase_cloudsql_tier` | `string` | `null` | `"db-f1-micro"` |
| `metabase_cloudsql_disk_size` | `any` | `null` | `10` |

### Features

| Variable | Type | Default | Example |
|---|---|---|---|
| `enable_cloud_armor` | `bool` | `false` | `true` |
| `enable_dicom` | `bool` | `false` | `false` |
| `enable_legacy_ingress` | `bool` | `false` | `false` |
| `enable_github_wif` | `bool` | `false` | `true` |
| `github_repo` | `string` | `""` | `"example-org/example-repo"` |

### Runtime App Config

| Variable | Type | Default | Example |
|---|---|---|---|
| `jwks_base64` | `string` | `""` | `"CHANGE_ME_BASE64_JWKS"` |
| `helm_config` | `map(map(string))` | `{}` | repo/tag map by service |
| `additional_secrets` | `map(string)` | `{}` | non-sensitive placeholders only |
| `additional_config_map_data` | `map(string)` | `{}` | app config overrides |
| `snowstorm_deployment_url` | `string` | `"https://terminology.10bedicu.in/fhir"` | `"https://terminology.example.org/fhir"` |
| `metabase_encryption_secret_key_override` | `string` | `null` | `null` |

### Optional Naming Overrides

| Variable | Type | Default |
|---|---|---|
| `namespace_name` | `string` | `null` |
| `cluster_name` | `string` | `null` |
| `vpc_network_name` | `string` | `null` |
| `database_subnet_name` | `string` | `null` |
| `gke_subnet_name` | `string` | `null` |
| `pods_range_name` | `string` | `null` |
| `services_range_name` | `string` | `null` |
| `gateway_ip_name` | `string` | `null` |
| `legacy_ingress_ip_name` | `string` | `null` |
| `legacy_fe_ip_name` | `string` | `null` |
| `flow_logs_bucket` | `string` | `null` |
| `cloudsql_private_ip_name` | `string` | `null` |
| `nat_ip_address_name` | `string` | `null` |
