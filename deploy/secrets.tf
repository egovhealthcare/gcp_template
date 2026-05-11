resource "kubernetes_secret" "care_backend" {
  metadata {
    name      = "care-backend-secret"
    namespace = local.namespace_name
    labels    = local.common_labels
  }
  type       = "Opaque"
  data       = { for k, v in local.secret_data : k => v }
  depends_on = [kubernetes_namespace.care_namespace]
}

resource "kubernetes_secret" "metabase" {
  metadata {
    name      = "metabase-secret"
    namespace = local.namespace_name
    labels    = local.common_labels
  }
  type       = "Opaque"
  data       = { for k, v in local.metabase_secret_data : k => v }
  depends_on = [kubernetes_namespace.care_namespace]
}

resource "kubernetes_secret" "dcm4chee" {
  count = var.enable_dicom ? 1 : 0
  metadata {
    name      = "dcm4chee-secret"
    namespace = local.namespace_name
    labels    = local.common_labels
  }
  type       = "Opaque"
  data       = { for k, v in local.dicom_secret_data : k => v }
  depends_on = [kubernetes_namespace.care_namespace]
}

resource "random_password" "dicom_webhook_secret" {
  length  = 64
  special = false
}

resource "random_password" "ldap_admin_password" {
  length  = 32
  special = false
}
