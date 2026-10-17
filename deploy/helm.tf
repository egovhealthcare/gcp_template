# Helm Chart for Gateway Deployment
resource "helm_release" "gateway" {
  name        = "gateway"
  chart       = "${path.module}/../helm_charts/gateway"
  namespace   = local.namespace_name
  max_history = 10
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.gateway_values, { chartHash = local.chart_hashes.gateway }))
  ]

  depends_on = [
    kubernetes_namespace.care_namespace,
    helm_release.cert_manager,
    kubernetes_secret.domain_tls_placeholder,
    kubernetes_secret.external_tls,
    kubernetes_secret.acme_account_key,
  ]

  lifecycle {
    ignore_changes = [metadata]

    precondition {
      condition     = length(local.gateway_certificate_refs) <= 15
      error_message = "The HTTPS listener supports at most 15 certificates, one per domain plus the external one. Got ${length(local.gateway_certificate_refs)}."
    }
    precondition {
      condition     = length(distinct(values(local.certificate_names))) == length(local.certificate_names)
      error_message = "Two domains map to the same certificate name (dots and dashes both become \"-\"). Rename one of them."
    }
  }
}

# cert-manager: Installs cert-manager controller + CRDs from Jetstack Helm repo
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.19.4"
  namespace        = "cert-manager"
  create_namespace = true
  max_history      = 10

  # Install CRDs (Certificate, ClusterIssuer, etc.)
  set {
    name  = "crds.enabled"
    value = "true"
  }

  # Enable Gateway API support (config-based, replaces deprecated featureGates flag)
  set {
    name  = "config.apiVersion"
    value = "controller.config.cert-manager.io/v1alpha1"
  }

  set {
    name  = "config.kind"
    value = "ControllerConfiguration"
  }

  set {
    name  = "config.enableGatewayAPI"
    value = "true"
  }

  # # Use external nameservers for HTTP-01 self-check DNS resolution
  # set {
  #   name  = "extraArgs[0]"
  #   value = "--acme-http01-solver-nameservers=8.8.8.8:53\\,1.1.1.1:53"
  # }

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Helm Chart for Redis Deployment
resource "helm_release" "redis" {
  name        = "redis"
  chart       = "${path.module}/../helm_charts/redis"
  namespace   = local.namespace_name
  max_history = 10
  # create_namespace = true

  values = [
    yamlencode(merge(local.redis_values, { chartHash = local.chart_hashes.redis }))
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Helm Chart for CARE Metrics Exporter
moved {
  from = helm_release.care_metrics_exporter[0]
  to   = helm_release.care_metrics_exporter
}

resource "helm_release" "care_metrics_exporter" {
  name        = "care-metrics-exporter"
  chart       = "${path.module}/../helm_charts/care_metrics_exporter"
  namespace   = local.namespace_name
  max_history = 10

  values = [
    yamlencode(merge(
      local.care_metrics_exporter_values,
      { chartHash = local.chart_hashes.care_metrics_exporter },
    ))
  ]

  depends_on = [
    helm_release.redis,
    kubernetes_secret.care_backend,
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Helm Chart for Metabase Deployment
resource "helm_release" "metabase" {
  name        = "metabase"
  chart       = "${path.module}/../helm_charts/metabase"
  namespace   = local.namespace_name
  timeout     = 420
  max_history = 10
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.metabase_values, { chartHash = local.chart_hashes.metabase })),
  ]

  depends_on = [
    helm_release.gateway,
    kubernetes_secret.metabase,
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Helm Chart for Care Backend Deployment
resource "helm_release" "care_backend" {
  name        = "care-backend"
  chart       = "${path.module}/../helm_charts/care_be"
  namespace   = local.namespace_name
  timeout     = 420
  max_history = 10
  # recreate_pods    = true 
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.care_backend_values, { chartHash = local.chart_hashes.care_be })),
  ]

  depends_on = [
    helm_release.gateway,
    kubernetes_secret.care_backend,
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}
# Helm Chart for Care Frontend Deployment
resource "helm_release" "care_frontend" {
  name        = "care-frontend"
  chart       = "${path.module}/../helm_charts/care_fe"
  namespace   = local.namespace_name
  max_history = 10
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.care_frontend_values, { chartHash = local.chart_hashes.care_fe }))
  ]

  depends_on = [
    helm_release.gateway,
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "helm_release" "dcm4chee" {
  count       = var.enable_dicom ? 1 : 0
  name        = "dcm4chee"
  chart       = "${path.module}/../helm_charts/dcm4chee"
  namespace   = local.namespace_name
  timeout     = 600
  max_history = 10

  values = [
    yamlencode(merge(local.common_helm_values, local.dcm4chee_values, { chartHash = local.chart_hashes.dcm4chee })),
  ]

  depends_on = [
    helm_release.gateway,
    helm_release.care_backend,
    kubernetes_secret.dcm4chee,
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "tls_private_key" "gateway_placeholder" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "gateway_placeholder" {
  private_key_pem = tls_private_key.gateway_placeholder.private_key_pem

  subject {
    common_name = "care.local"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Placeholders copy the old multi-domain Secret when it exists, so HTTPS stays
# valid until cert-manager issues the per-domain certificates.
data "kubernetes_resources" "legacy_gateway_tls" {
  api_version    = "v1"
  kind           = "Secret"
  namespace      = local.namespace_name
  field_selector = "metadata.name=${local.legacy_gateway_tls_secret_name}"
}

locals {
  legacy_gateway_tls = try(data.kubernetes_resources.legacy_gateway_tls.objects[0].data, null)

  placeholder_tls = local.legacy_gateway_tls != null ? {
    "tls.crt" = base64decode(local.legacy_gateway_tls["tls.crt"])
    "tls.key" = base64decode(local.legacy_gateway_tls["tls.key"])
    } : {
    "tls.crt" = tls_self_signed_cert.gateway_placeholder.cert_pem
    "tls.key" = tls_private_key.gateway_placeholder.private_key_pem
  }
}

resource "kubernetes_secret" "domain_tls_placeholder" {
  for_each = local.domain_certificates

  metadata {
    name      = each.value.secretName
    namespace = local.namespace_name
    annotations = {
      "cert-manager.io/placeholder" = "true"
    }
  }

  type = "kubernetes.io/tls"
  data = local.placeholder_tls

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubernetes_namespace.care_namespace]
}

# Keep the old multi-domain Secret in the cluster; it seeds the placeholders
removed {
  from = kubernetes_secret.gateway_tls_placeholder

  lifecycle {
    destroy = false
  }
}

resource "kubernetes_secret" "acme_account_key" {
  count = var.tls_certificate_issuer == "google" ? 1 : 0

  metadata {
    name      = local.acme_issuer.privateKeySecretName
    namespace = helm_release.cert_manager.namespace
  }

  data = {
    "tls.key" = local.acme_account_private_key
  }

  lifecycle {
    precondition {
      condition     = local.acme_account_private_key != null
      error_message = "tls_certificate_issuer is \"google\" but infra/ has no ACME account yet. Apply pre-infra/ and infra/ first."
    }
  }
}
