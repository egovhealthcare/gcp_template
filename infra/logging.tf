# GCS Bucket for indefinite log archival (CMEK, locked retention)
module "logs_bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 10.0"
  count   = var.enable_log_export ? 1 : 0

  project_id = var.project_id
  location   = var.region
  names      = [local.logs_bucket_name]
  labels = merge(
    local.tags,
    {
      billing = "logs-bucket"
    }
  )

  bucket_policy_only = {
    (local.logs_bucket_name) = true
  }

  lifecycle_rules = [{
    action = {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition = {
      age = 90
    }
    }, {
    action = {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
    condition = {
      age = 365
    }
  }]

  encryption_key_names = {
    (local.logs_bucket_name) = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.org}-${var.app}-${var.environment}-keyring/cryptoKeys/logs-key"
  }
}

# Grant KMS permissions to Storage service account for logs bucket
resource "google_kms_crypto_key_iam_member" "storage_sa_logs" {
  count         = var.enable_log_export ? 1 : 0
  crypto_key_id = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.org}-${var.app}-${var.environment}-keyring/cryptoKeys/logs-key"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_logging_project_bucket_config" "regional" {
  count = var.enable_log_export ? 1 : 0

  project        = var.project_id
  location       = var.region
  bucket_id      = local.logging_bucket_id
  retention_days = 30
  locked         = true

  cmek_settings {
    kms_key_name = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.org}-${var.app}-${var.environment}-keyring/cryptoKeys/logs-key"
  }
}

# Grant KMS permissions to Cloud Logging service account
resource "google_kms_crypto_key_iam_member" "logging_sa_logs" {
  count         = var.enable_log_export ? 1 : 0
  crypto_key_id = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.org}-${var.app}-${var.environment}-keyring/cryptoKeys/logs-key"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-logging.iam.gserviceaccount.com"
}

# Sink: ALL logs → GCS bucket (indefinite archival)
resource "google_logging_project_sink" "all_logs_to_gcs" {
  count = var.enable_log_export ? 1 : 0

  name                   = "all-logs-to-gcs"
  project                = var.project_id
  destination            = "storage.googleapis.com/${module.logs_bucket[0].name}"
  unique_writer_identity = true

  # Empty filter = match ALL logs
}

# Sink: ALL logs → Regional Cloud Logging bucket (live querying in India)
resource "google_logging_project_sink" "all_logs_to_regional" {
  count = var.enable_log_export ? 1 : 0

  name                   = "all-logs-to-regional"
  project                = var.project_id
  destination            = "logging.googleapis.com/projects/${var.project_id}/locations/${var.region}/buckets/${local.logging_bucket_id}"
  unique_writer_identity = true

  # Empty filter = match ALL logs

  depends_on = [google_logging_project_bucket_config.regional]
}

resource "google_logging_project_exclusion" "exclude_all_from_default" {
  count = var.enable_log_export ? 1 : 0

  name        = "exclude-all-from-default"
  project     = var.project_id
  description = "Exclude all logs from _Default bucket to enforce data residency in ${var.region}"

  # Match all log entries (routes them only to regional + GCS)
  filter = "LOG_ID(\"*\")"
}

resource "google_project_iam_audit_config" "all_services" {
  count   = var.enable_log_export ? 1 : 0
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

# GCS sink writer → storage.objectCreator on logs bucket
resource "google_storage_bucket_iam_member" "logs_sink_writer" {
  count  = var.enable_log_export ? 1 : 0
  bucket = module.logs_bucket[0].name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.all_logs_to_gcs[0].writer_identity
}

# Regional sink writer → logging.bucketWriter on regional logging bucket
resource "google_project_iam_member" "regional_sink_writer" {
  count   = var.enable_log_export ? 1 : 0
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_project_sink.all_logs_to_regional[0].writer_identity

  condition {
    title       = "regional-logging-bucket-only"
    description = "Restrict to the regional logging bucket"
    expression  = "resource.name.endsWith(\"locations/${var.region}/buckets/${local.logging_bucket_id}\")"
  }
}
