---
applyTo: "**/*.tf"
description: "Terraform/OpenTofu conventions for this GCP infrastructure project"
---

# Terraform Conventions

## Module Structure

Modules (apply in order):

- `pre-infra/` : bootstrap (APIs, optional DNS zone)
- `infra/` : VPC, GKE, Cloud SQL, buckets, Cloud Armor, GitHub WIF
- `KMS/` : key ring and crypto keys
- `deploy/` : namespace, secrets, Helm releases

Typical files per module:

- `init.tf` : providers, backend, remote state data sources
- `variables.tf` : **symlink** to root shared variable contract — edit the root file only
- Resource files by domain (`network.tf`, `cloud-sql.tf`, `helm.tf`, etc.)
- `outputs.tf` : exported values for downstream modules
- `locals.tf` : derived values, naming, secret composition

## Provider Versions

All modules pin: `google`/`google-beta` `~> 6.33`, `random ~> 3.7`, OpenTofu `~> 1.11`.
`deploy/` additionally requires: `kubernetes ~> 2.0`, `helm ~> 2.0`, `tls ~> 4.0`, `local ~> 2.0`.

## Configuration Pattern

- Modules consume tfvars values directly via `var.*`.
- Runtime tfvars file path convention: `../environments/<env>.tfvars`.
- Secret Manager name convention: `tofu-tfvars-<env>`.
- Never introduce `local.cfg` / JSON decode flows for configuration.

## Optional Overrides

Use direct variable coalesce for optional naming overrides:

```hcl
name = coalesce(var.cluster_name, "${var.org}-${var.app}-${var.environment}")
```

## Feature Flags

Use booleans from variables and gate resources with `count` / `for_each`:

```hcl
count = var.enable_dicom ? 1 : 0
```

Current flags: `enable_dicom`, `enable_cloud_armor`, `enable_github_wif`, `enable_legacy_ingress`, `enable_dns_zone`.

## Cross-Module References

`deploy/init.tf` reads remote state from:
- `infra` (prefix `infra`) — network, cluster, database, platform outputs
- `keys` (prefix `keys`) — KMS key outputs

Access pattern: `data.terraform_remote_state.infra.outputs.<key>`.

## State Backend

GCS backend with prefixes: `pre-infra`, `infra`, `keys`, `deploy-backend`.
`deploy/` plan uses `-lock=false`; all other modules lock normally.

## Adding Secrets

1. Add the key-value pair to `local.secret_data` (or `local.metabase_secret_data` / `local.dicom_secret_data`) in `deploy/locals.tf`.
2. The corresponding `kubernetes_secret` in `deploy/secrets.tf` references the local map — no additional wiring needed.
3. If the secret value comes from infrastructure, ensure the upstream module exports it in `outputs.tf`.

## Adding Helm Charts

1. Create chart under `helm_charts/<name>/` following existing chart patterns.
2. Define generated values in `deploy/helm-values.tf` as a `local_file` resource.
3. Add a `helm_release` resource in `deploy/helm.tf`, merging `common_helm_values` with chart-specific values.
4. Image config comes from `var.helm_config.<chart_key>` (add to `helm_config` variable and `sample.tfvars`).

## Deploy-Specific Variables

`deploy/variables.tf` extends the root contract with: `helm_config`, `additional_secrets`, `additional_config_map_data`, `enable_legacy_ingress`, `jwks_base64`, `namespace_name`, and various resource name overrides. See `environments/sample.tfvars` for the full shape.

## tfvars Workflow

All modules support Makefile targets: `pull-tfvars`, `push-tfvars`, `plan`, `deploy`.
Scripts: `scripts/tfvars-pull.sh` (pulls from Secret Manager), `scripts/tfvars-push.sh` (pushes and verifies SHA256).
