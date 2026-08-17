# Copilot Instructions

GCP infrastructure-as-code for the CARE healthcare application, built with OpenTofu and Helm on GKE.

## Architecture

Four modules applied in strict order — deploying out of order will fail:

```
pre-infra/  →  infra/  →  KMS/  →  deploy/
(APIs, DNS)    (VPC,      (keys,    (K8s ns,
               GKE,       secrets)   Helm
               SQL,                  releases)
               GCS)
```

`deploy/` reads remote state from `infra` (prefix `infra`) and `KMS` (prefix `keys`) via `terraform_remote_state` in `deploy/init.tf`.

### Secrets flow

```
infra/ (DB passwords, HMAC keys) ──┐
                                    ├─→ deploy/locals.tf (secret maps) ─→ kubernetes_secret ─→ Pods
KMS/ (Django secrets, Metabase key) ┘
```

Three secret maps in `deploy/locals.tf`: `secret_data`, `metabase_secret_data`, `dicom_secret_data`. To add a new secret, add the key-value pair to the appropriate map — the `kubernetes_secret` in `deploy/secrets.tf` picks it up automatically.

## Build and Lint Commands

Run from any module directory. Required env vars: `PROJECT_ID`, `ENV_NAME`, `BACKEND_BUCKET`.

```bash
make init                    # tofu init with GCS backend
make pull-tfvars             # fetch tfvars from Secret Manager
make plan                    # tofu plan
make deploy                  # tofu apply
make lint                    # tofu fmt -recursive
make push-tfvars             # push local tfvars to Secret Manager
```

There are no unit tests in this repository. Validation is done via `make plan`.

## Key Conventions

### Shared variables.tf

The root `variables.tf` is **symlinked** into every module directory. Always edit the root copy — never create separate copies.

### Naming pattern

Resources follow `{org}-{app}-{environment}` with resource-specific suffixes. Override any derived name with `coalesce(var.override, derived_default)`.

### Feature flags

Boolean variables gate optional infrastructure via `count`:

| Flag | Controls |
|------|----------|
| `enable_dicom` | DICOM stack (requires `dicom_domain_name` to be non-empty) |
| `enable_cloud_armor` | Cloud Armor security policies |
| `enable_github_wif` | GitHub Actions Workload Identity Federation |
| `enable_legacy_ingress` | Legacy GCE Ingress resources |
| `enable_dns_zone` | Cloud DNS managed zone |

### Helm value injection

Chart-specific values are locals in `deploy/helm-values.tf`, passed to `helm_release` in `deploy/helm.tf` via `yamlencode()`. They merge with `common_helm_values` from `deploy/locals.tf`. Image config comes from `var.helm_config.<chart_key>`.

### State backend prefixes

| Module | Prefix |
|--------|--------|
| `pre-infra/` | `pre-infra` |
| `infra/` | `infra` |
| `KMS/` | `keys` |
| `deploy/` | `deploy-backend` |

## Common Pitfalls

- **Never commit real tfvars** — store them in Secret Manager (`tofu-tfvars-<env>`).
- **`additional_plugs`** is a top-level tfvar overwritten by the deploy pipeline. Do not set `ADDITIONAL_PLUGS` inside `additional_config_map_data` — it would override the top-level value.
- **`external_tls_cert` and `external_tls_key`** must both be set or both null.
- **`deploy/` uses `-lock=false`** for `tofu plan`. All other modules lock normally.

## Detailed Conventions

File-pattern-specific instructions are auto-applied by Copilot:

- `**/*.tf` → [`.github/instructions/terraform.instructions.md`](.github/instructions/terraform.instructions.md)
- `helm_charts/**` → [`.github/instructions/helm.instructions.md`](.github/instructions/helm.instructions.md)

See also: [`AGENTS.md`](../AGENTS.md) for the full project guidelines reference.
