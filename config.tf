# Fetch environment config from GCP Secret Manager.
# All configuration is stored as a single JSON secret per environment.
# Only 3 bootstrap variables are needed: project_id, region, env_name.
data "google_secret_manager_secret_version" "config" {
  secret  = "tofu-env-${var.env_name}"
  project = var.project_id
}

locals {
  cfg = nonsensitive(jsondecode(data.google_secret_manager_secret_version.config.secret_data))
}