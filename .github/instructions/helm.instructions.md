---
applyTo: "helm_charts/**"
description: "Helm chart conventions for CARE application Kubernetes deployments"
---

# Helm Chart Conventions

## Chart Layout

Each chart under `helm_charts/` includes:

- `Chart.yaml` — chart metadata
- `values.yaml` — default values (overridden by Terraform-generated values)
- `templates/_helpers.tpl` — shared naming/label helpers
- Workload, service, and routing templates

Current charts: `gateway`, `redis`, `metabase`, `care_be`, `care_fe`, `dcm4chee`.

## Common Helpers (`_helpers.tpl`)

All charts use an identical set of helper templates:

| Helper | Purpose |
|--------|---------|
| `CHART.name` | Chart name, respects `nameOverride`, truncates to 63 chars |
| `CHART.fullname` | Includes release name, respects `fullnameOverride` |
| `CHART.chart` | `{Chart.Name}-{Chart.Version}`, replaces `+` with `_` |
| `CHART.labels` | Standard Kubernetes labels (chart, selector, version, managed-by) |
| `CHART.selectorLabels` | `app.kubernetes.io/name` and `app.kubernetes.io/instance` |
| `CHART.serviceAccountName` | Conditional on `serviceAccount.create`, fallback to `default` |

When creating a new chart, copy an existing `_helpers.tpl` and replace the chart name prefix.

## Deployment Patterns

- Use checksum annotations for ConfigMap/Secret-driven rolling updates:
  ```yaml
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  ```
- Keep resource requests/limits explicit in `values.yaml`.
- Keep liveness/readiness probes explicit.

## Global Values Contract

Terraform injects a `global` block via `common_helm_values` in `deploy/locals.tf`:

```yaml
global:
  cloudProvider: gcp
  namespace: <namespace>
  gateway:
    name: care-regional-gateway
    namespace: <namespace>
    gatewayClassName: gke-l7-regional-external-managed
  backendPolicy:
    enabled: true
    securityPolicy: <cloud-armor-policy-name>
  httpRoute:
    enabled: true
```

Charts should reference `global.*` for gateway routing and backend policy configuration.

## Terraform Value Injection

- Chart-specific values are generated in `deploy/helm-values.tf` as YAML files under `deploy/generated_values/`.
- Image config comes from `var.helm_config.<chart_key>` with `repository` and `tag` keys.
- Domain hostnames for HTTPRoute come from `var.web_domain_name`, `var.api_domain_name`, etc.
- Secret references use `envFromSecret` pointing to Kubernetes secrets created in `deploy/secrets.tf`.

## Routing

- Gateway API resources (HTTPRoute, Gateway) are the default routing pattern.
- Legacy GCE Ingress is optional, controlled by `enable_legacy_ingress` feature flag in Terraform.
- Each chart with external access includes `httproute.yaml` and `backend-policy.yaml` templates.

## Adding a New Chart

1. Create `helm_charts/<name>/` with `Chart.yaml`, `values.yaml`, and `templates/`.
2. Copy `_helpers.tpl` from an existing chart, update the template name prefix.
3. Add Terraform value generation in `deploy/helm-values.tf`.
4. Add `helm_release` resource in `deploy/helm.tf` merging `common_helm_values`.
5. Add image config to `helm_config` variable and `environments/sample.tfvars`.
