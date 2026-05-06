locals {
  required_tags = {
    terraform   = "true"
    environment = local.cfg["environment"]
    project     = "care"
  }

  common_labels = {
    app         = "care"
    environment = local.cfg["environment"]
    project     = "care"
  }
  tags                 = merge(local.required_tags)
  patient_bucket_name  = data.terraform_remote_state.infra.outputs.patient_bucket_name
  facility_bucket_name = data.terraform_remote_state.infra.outputs.facility_bucket_name
  writer_sa_email      = data.terraform_remote_state.infra.outputs.writer_service_account_email

  namespace_name              = coalesce(lookup(local.cfg, "namespace_name", null), local.cfg["environment"])
  app_name                    = local.cfg["app"]
  environment                 = local.cfg["environment"]
  gateway_name                = "care-regional-gateway"
  certmanager_tls_secret_name = "${local.cfg["org"]}-${local.cfg["app"]}-${local.cfg["environment"]}-gateway-tls"

  metabase_secret_data = {
    MB_DB_TYPE               = "postgres"
    MB_DB_DBNAME             = data.terraform_remote_state.infra.outputs.metabase_database_name
    MB_DB_PORT               = "5432"
    MB_DB_USER               = data.terraform_remote_state.infra.outputs.metabase_database_user
    MB_DB_PASS               = data.terraform_remote_state.infra.outputs.metabase_database_password
    MB_DB_HOST               = data.terraform_remote_state.infra.outputs.metabase_instance_address
    MB_ENCRYPTION_SECRET_KEY = coalesce(lookup(local.cfg, "metabase_encryption_secret_key_override", null), data.terraform_remote_state.keys.outputs.metabase_encryption_secret_key)
    MB_SITE_NAME             = "CARE Dashboard"
  }

  config_map_data = merge({
    POSTGRES_PORT                            = 5432
    DJANGO_SECURE_SSL_REDIRECT               = "False"
    DJANGO_SETTINGS_MODULE                   = "config.settings.production"
    BUCKET_PROVIDER                          = "gcp"
    BUCKET_REGION                            = var.region
    CSRF_TRUSTED_ORIGINS                     = jsonencode(concat([for d in local.cfg["web_domain_name"] : "https://${d}"], [for d in local.cfg["api_domain_name"] : "https://${d}"]))
    DJANGO_ALLOWED_HOSTS                     = jsonencode(["*"])
    CORS_ALLOWED_ORIGINS                     = jsonencode([for d in local.cfg["web_domain_name"] : "https://${d}"])
    RATE_LIMIT                               = "5/10m"
    AWS_REQUEST_CHECKSUM_CALCULATION         = "when_required"
    SNOWSTORM_DEPLOYMENT_URL                 = lookup(local.cfg, "snowstorm_deployment_url", "https://terminology.10bedicu.in/fhir")
    MAINTAIN_PATIENT_PHONE_NUMBER_IDENTIFIER = "true"
  }, lookup(local.cfg, "additional_config_map_data", {}))

  secret_data = merge({
    DJANGO_SECRET_KEY           = data.terraform_remote_state.keys.outputs.django_secret_key
    POSTGRES_DB                 = data.terraform_remote_state.infra.outputs.database_name
    POSTGRES_USER               = data.terraform_remote_state.infra.outputs.database_user
    POSTGRES_HOST               = data.terraform_remote_state.infra.outputs.instance_address
    POSTGRES_PASSWORD           = data.terraform_remote_state.infra.outputs.database_password
    BUCKET_KEY                  = data.terraform_remote_state.infra.outputs.gcs_access_key
    BUCKET_SECRET               = data.terraform_remote_state.infra.outputs.gcs_secret_key
    CELERY_BROKER_URL           = "redis://redis.${local.namespace_name}.svc.cluster.local:6379/0"
    FILE_UPLOAD_BUCKET          = local.patient_bucket_name
    FACILITY_S3_BUCKET          = local.facility_bucket_name
    REDIS_URL                   = "redis://redis.${local.namespace_name}.svc.cluster.local:6379/0"
    DJANGO_ADMIN_URL            = data.terraform_remote_state.keys.outputs.django_admin_password
    DATABASE_URL                = data.terraform_remote_state.infra.outputs.primary_connection_string
    JWKS_BASE64                 = local.cfg["jwks_base64"]
    FILE_UPLOAD_BUCKET_ENDPOINT = "https://storage.googleapis.com"
    FACILITY_S3_BUCKET_ENDPOINT = "https://storage.googleapis.com"
  }, lookup(local.cfg, "additional_secrets", {}))

  common_helm_values = {
    global = {
      cloudProvider = "gcp"
      namespace     = local.namespace_name
      gateway = {
        name             = local.gateway_name
        namespace        = local.namespace_name
        gatewayClassName = "gke-l7-regional-external-managed"
      }
      backendPolicy = {
        enabled        = true
        securityPolicy = data.terraform_remote_state.infra.outputs.security_policy_name
      }
      httpRoute = {
        enabled = true
      }
    }
  }

  # Care backend service port (used by DICOM nginx auth proxy)
  care_backend_port = 9000

  # Legacy ingress support (opt-in via config)
  enable_legacy_ingress  = lookup(local.cfg, "enable_legacy_ingress", false)
  legacy_ingress_ip_name = coalesce(lookup(local.cfg, "legacy_ingress_ip_name", null), "care-pip")
  legacy_fe_ip_name      = coalesce(lookup(local.cfg, "legacy_fe_ip_name", null), "care-fe")

  # DICOM secret data (only evaluated when enable_dicom = true)
  dicom_secret_data = lookup(local.cfg, "enable_dicom", false) ? {
    POSTGRES_DB         = data.terraform_remote_state.infra.outputs.dicom_database_name
    POSTGRES_USER       = data.terraform_remote_state.infra.outputs.dicom_database_user
    POSTGRES_PASSWORD   = data.terraform_remote_state.infra.outputs.dicom_database_password
    POSTGRES_HOST       = data.terraform_remote_state.infra.outputs.instance_address
    DATABASE_URL        = data.terraform_remote_state.infra.outputs.dicom_connection_string
    LDAP_ADMIN_PASSWORD = random_password.ldap_admin_password.result
    DICOM_BUCKET_NAME   = data.terraform_remote_state.infra.outputs.dicom_bucket_name
    GCS_ACCESS_KEY      = data.terraform_remote_state.infra.outputs.gcs_access_key
    GCS_SECRET_KEY      = data.terraform_remote_state.infra.outputs.gcs_secret_key
  } : {}
}
