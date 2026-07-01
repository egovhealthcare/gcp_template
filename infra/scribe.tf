locals {
  scribe_sa_name = coalesce(var.scribe_sa_name, "gemini-scribe")
}

resource "google_service_account" "scribe" {
  count = var.enable_scribe ? 1 : 0

  project      = var.project_id
  account_id   = local.scribe_sa_name
  display_name = "Gemini Scribe (${var.environment})"
  description  = "Service account for CARE Scribe AI features (Vertex AI)"
}

resource "google_project_iam_member" "scribe_aiplatform_user" {
  count = var.enable_scribe ? 1 : 0

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.scribe[0].email}"
}

resource "google_service_account_key" "scribe" {
  count = var.enable_scribe ? 1 : 0

  service_account_id = google_service_account.scribe[0].name
}
