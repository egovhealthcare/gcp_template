# Helm Chart for Gateway Deployment
resource "helm_release" "gateway" {
  name      = "gateway"
  chart     = "${path.module}/../helm_charts/gateway"
  namespace = local.namespace_name
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.gateway_values))
  ]

  depends_on = [
    kubernetes_namespace.care_namespace,
    helm_release.cert_manager,
    kubernetes_secret.gateway_tls_placeholder,
    kubernetes_secret.external_tls,
  ]
}

# cert-manager: Installs cert-manager controller + CRDs from Jetstack Helm repo
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.19.4"
  namespace        = "cert-manager"
  create_namespace = true

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
}

# Helm Chart for Redis Deployment
resource "helm_release" "redis" {
  name      = "redis"
  chart     = "${path.module}/../helm_charts/redis"
  namespace = local.namespace_name
  # create_namespace = true

  values = [
    yamlencode(local.redis_values)
  ]
}
# Helm Chart for Metabase Deployment
resource "helm_release" "metabase" {
  name      = "metabase"
  chart     = "${path.module}/../helm_charts/metabase"
  namespace = local.namespace_name
  timeout   = 420
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.metabase_values)),
  ]

  depends_on = [
    helm_release.gateway,
    kubernetes_secret.metabase,
  ]
}

# Helm Chart for Care Backend Deployment
resource "helm_release" "care_backend" {
  name      = "care-backend"
  chart     = "${path.module}/../helm_charts/care_be"
  namespace = local.namespace_name
  timeout   = 420
  # recreate_pods    = true 
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.care_backend_values)),
  ]

  depends_on = [
    helm_release.gateway,
    kubernetes_secret.care_backend,
  ]
}
# Helm Chart for Care Frontend Deployment
resource "helm_release" "care_frontend" {
  name      = "care-frontend"
  chart     = "${path.module}/../helm_charts/care_fe"
  namespace = local.namespace_name
  # create_namespace = true

  values = [
    yamlencode(merge(local.common_helm_values, local.care_frontend_values))
  ]

  depends_on = [
    helm_release.gateway,
  ]
}

resource "helm_release" "dcm4chee" {
  count     = var.enable_dicom ? 1 : 0
  name      = "dcm4chee"
  chart     = "${path.module}/../helm_charts/dcm4chee"
  namespace = local.namespace_name
  timeout   = 600

  values = [
    yamlencode(merge(local.common_helm_values, local.dcm4chee_values)),
  ]

  depends_on = [
    helm_release.gateway,
    helm_release.care_backend,
    kubernetes_secret.dcm4chee,
  ]
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

resource "kubernetes_secret" "gateway_tls_placeholder" {
  metadata {
    name      = local.certmanager_tls_secret_name
    namespace = local.namespace_name
    annotations = {
      "cert-manager.io/placeholder" = "true"
    }
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.gateway_placeholder.cert_pem
    "tls.key" = tls_private_key.gateway_placeholder.private_key_pem
  }

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubernetes_namespace.care_namespace]
}
