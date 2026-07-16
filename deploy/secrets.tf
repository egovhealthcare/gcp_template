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

resource "kubernetes_secret" "external_tls" {
  count = var.external_tls_cert != null ? 1 : 0

  metadata {
    name      = local.external_tls_secret_name
    namespace = local.namespace_name
    labels    = local.common_labels
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.external_tls_cert
    "tls.key" = var.external_tls_key
  }

  depends_on = [kubernetes_namespace.care_namespace]
}

resource "kubernetes_secret" "metabase_etl" {
  metadata {
    name      = "metabase-etl-secret"
    namespace = local.namespace_name
    labels    = local.common_labels
  }
  type = "Opaque"
  data = {
      WAREHOUSE_URL          = "postgresql://${data.terraform_remote_state.infra.outputs.metabase_database_user}:${data.terraform_remote_state.infra.outputs.metabase_database_password}@${data.terraform_remote_state.infra.outputs.metabase_instance_address}:5432/metabase_warehouse"
      POSTGRES_URL           = "postgresql://${data.terraform_remote_state.infra.outputs.metabase_database_user}:${data.terraform_remote_state.infra.outputs.metabase_database_password}@${data.terraform_remote_state.infra.outputs.metabase_instance_address}:5432/postgres"
      CARE_SOURCE_URL        = "postgresql://${data.terraform_remote_state.infra.outputs.database_user}:${data.terraform_remote_state.infra.outputs.database_password}@${data.terraform_remote_state.infra.outputs.instance_address}:5432/${var.app}_${var.environment}"
      WAREHOUSE_DB           = "metabase_warehouse"
      SOURCE_REPLICA_HOST    = data.terraform_remote_state.infra.outputs.read_replica_address
      SOURCE_DBNAME          = "${var.app}_${var.environment}"
      WAREHOUSE_ETL_PASSWORD    = data.terraform_remote_state.keys.outputs.warehouse_etl_password
      FDW_READER_PASSWORD       = data.terraform_remote_state.keys.outputs.warehouse_fdw_reader_password
      METABASE_READER_PASSWORD  = data.terraform_remote_state.keys.outputs.metabase_reader_password
  }
  depends_on = [kubernetes_namespace.care_namespace]
}

resource "random_password" "dicom_webhook_secret" {
  count   = var.enable_dicom ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "ldap_admin_password" {
  length  = 32
  special = false
}
