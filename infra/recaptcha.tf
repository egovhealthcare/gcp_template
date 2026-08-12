locals {
  recaptcha_key_display_name = coalesce(var.recaptcha_key_display_name, "${var.org}-${var.app}-${var.environment}")

  recaptcha_allowed_domains = distinct(concat(var.web_domain_name, var.api_domain_name, var.recaptcha_additional_domains))
}

# The key is always provisioned so that toggling var.enable_recaptcha off in the deploy
# module only stops the secrets from reaching the workload.
resource "google_recaptcha_enterprise_key" "care" {
  project      = var.project_id
  display_name = local.recaptcha_key_display_name
  labels       = local.common_labels

  web_settings {
    integration_type  = var.recaptcha_integration_type
    allow_all_domains = length(local.recaptcha_allowed_domains) == 0
    allowed_domains   = local.recaptcha_allowed_domains
    # Only valid for the CHECKBOX and INVISIBLE integration types.
    challenge_security_preference = var.recaptcha_integration_type == "SCORE" ? null : "BALANCED"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_client_config" "default" {}

# The provider exposes no legacy secret key, so it is fetched from the
# projects.keys.retrieveLegacySecretKey REST method. That secret is what
# CARE's backend uses against https://www.google.com/recaptcha/api/siteverify.
data "external" "recaptcha_legacy_secret" {
  program = ["bash", "${path.module}/scripts/fetch-recaptcha-legacy-secret.sh"]

  query = {
    key_name     = "projects/${var.project_id}/keys/${google_recaptcha_enterprise_key.care.name}"
    access_token = data.google_client_config.default.access_token
  }
}
