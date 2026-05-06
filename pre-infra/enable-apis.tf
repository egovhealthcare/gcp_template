module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id = var.project_id

  activate_apis = concat(
    [
      # --- Core (always required) ---
      "compute.googleapis.com",
      "storage.googleapis.com",
      "cloudkms.googleapis.com",
      "sqladmin.googleapis.com",
      "container.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "servicenetworking.googleapis.com",
      "serviceusage.googleapis.com",
      "iam.googleapis.com",
      "secretmanager.googleapis.com",
      "artifactregistry.googleapis.com",
    ],
    # --- Conditional ---
    lookup(local.cfg, "enable_billing_budget", false) ? [
      "monitoring.googleapis.com",
      "billingbudgets.googleapis.com",
      "cloudbilling.googleapis.com",
    ] : [],
    lookup(local.cfg, "enable_dns_zone", false) ? [
      "dns.googleapis.com",
    ] : [],
    lookup(local.cfg, "enable_github_wif", false) ? [
      "iamcredentials.googleapis.com",
    ] : [],
    lookup(local.cfg, "enable_cloud_build", false) ? [
      "cloudbuild.googleapis.com",
    ] : [],
    # "aiplatform.googleapis.com", # in case scribe is needed
  )

  enable_apis                 = true
  disable_services_on_destroy = false
}
