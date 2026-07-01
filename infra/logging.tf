resource "google_logging_project_bucket_config" "regional" {
  count = var.enable_log_export ? 1 : 0

  project        = var.project_id
  location       = var.region
  bucket_id      = local.logging_bucket_id
  retention_days = 365
  locked         = false

  cmek_settings {
    kms_key_name = local.logs_kms_key_id
  }

  depends_on = [google_kms_crypto_key_iam_member.logging_sa_logs]
}

resource "google_logging_project_bucket_config" "default" {
  count = var.enable_log_export ? 1 : 0

  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = 1
  locked         = false
}

# Grant KMS permissions to Cloud Logging service account
resource "google_kms_crypto_key_iam_member" "logging_sa_logs" {
  count         = var.enable_log_export ? 1 : 0
  crypto_key_id = local.logs_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-logging.iam.gserviceaccount.com"
}

# Sink: ALL logs → GCS bucket (long-term archive)
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

  filter = "true"
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
