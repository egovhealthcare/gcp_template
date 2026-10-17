# Repoints the _Default sink to a regional CMEK bucket. The _Required bucket
# (Admin Activity / System Event audit logs) stays in `global`; GCP does not allow changing it.

resource "google_logging_project_bucket_config" "regional" {
  project        = var.project_id
  location       = var.region
  bucket_id      = local.logging_bucket_id
  retention_days = 365

  cmek_settings {
    kms_key_name = local.logs_kms_key_id
  }

  depends_on = [google_kms_crypto_key_iam_member.logging_sa_logs]
}

# Reading the CMEK settings provisions the Cloud Logging service account.
data "google_logging_project_cmek_settings" "default" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "logging_sa_logs" {
  crypto_key_id = local.logs_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_logging_project_cmek_settings.default.service_account_id}"
}

# The _Default sink always exists, so adopt it instead of creating it.
import {
  to = google_logging_project_sink.default
  id = "projects/${var.project_id}/sinks/_Default"
}

resource "google_logging_project_sink" "default" {
  name        = "_Default"
  project     = var.project_id
  destination = "logging.googleapis.com/${google_logging_project_bucket_config.regional.id}"

  # Same filter GCP sets on _Default (everything except _Required audit logs).
  filter = join(" AND ", [
    "NOT LOG_ID(\"cloudaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")",
  ])

  unique_writer_identity = true
}

moved {
  from = google_logging_project_bucket_config.regional[0]
  to   = google_logging_project_bucket_config.regional
}

moved {
  from = google_kms_crypto_key_iam_member.logging_sa_logs[0]
  to   = google_kms_crypto_key_iam_member.logging_sa_logs
}

moved {
  from = google_logging_project_sink.default_sink[0]
  to   = google_logging_project_sink.default
}
