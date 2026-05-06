# Environment Config Notes

Use this folder for environment JSON examples and notes.

## Files

- `sample.json`: Full sample configuration payload for Secret Manager (`tofu-env-{env}`).
- `README.md`: Human-readable notes (this file).

## Why Notes Are Here

JSON does not support inline comments, and this repo validates config as strict JSON (`jq` + `jsondecode`).
So we keep explanations in this doc instead of adding comments inside `sample.json`.

## How To Use

1. Copy the sample:
   ```bash
   cp environments/sample.json /tmp/my-env-config.json
   ```
2. Edit values for your environment.
3. Bootstrap/update Secret Manager:
   ```bash
   ./scripts/bootstrap.sh --project=PROJECT_ID --env=ENV --file=/tmp/my-env-config.json
   ```

## Key Groups

- GCP project/location: `project_id`, `project_number`, `region`, `zones`, `zone`
- Naming: `org`, `app`, `environment`
- Domains: `web_domain_name`, `api_domain_name`, `metabase_domain_name`, `dicom_domain_name`
- DNS: `enable_dns_zone`, `dns_zone_domain`
- Network: `database_subnets`, `gke_subnets`, `gke_pods_range`, `gke_services_range`, `proxy_only_subnet_cidr`
- GKE pools: `node_pools`
- Cloud SQL: `cloudsql_tier`, `cloudsql_disk_size`, `cloudsql_read_replica_count`, `cloudsql_read_replica_tier`
- Metabase DB: `metabase_cloudsql_tier`, `metabase_cloudsql_disk_size`
- Feature flags: `enable_sentry`, `enable_dicom`, `enable_cloud_armor`
- App secrets/config: `jwks_base64`, `sentry_dsn`, `additional_secrets`, `additional_config_map_data`
- Billing budgets: `billing_budget_currency_code`, `billing_budget_monthly_amount`, `billing_budget_alert_emails`
- Overrides (optional): `cluster_name`, `namespace_name`, `vpc_network_name`, `database_subnet_name`, `gke_subnet_name`, `pods_range_name`, `services_range_name`, `ip_address_name`, `flow_logs_bucket`, `cloudsql_private_ip_name`

## Type Notes

- Keep numeric values as numbers (no quotes), for example:
  - `cloudsql_disk_size`: `10`
  - `cloudsql_read_replica_count`: `0`
- Keep boolean values as booleans:
  - `enable_dicom`: `false`
  - `enable_cloud_armor`: `true`
- In `node_pools`, use numeric/boolean types for fields like `min_count`, `max_count`, `preemptible`, `disk_size_gb`.
