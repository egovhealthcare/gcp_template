locals {
  recaptcha_allowed_domains = distinct(concat(var.web_domain_name, var.api_domain_name, var.recaptcha_additional_domains))
}

# The key is always provisioned so that toggling var.enable_recaptcha off in the deploy
# module only stops the secrets from reaching the workload.
resource "google_recaptcha_enterprise_key" "care" {
  project      = var.project_id
  display_name = "${var.org}-${var.app}-${var.environment}"
  labels       = local.common_labels

  web_settings {
    # CARE FE renders a v2 checkbox widget (react-google-recaptcha, g-recaptcha-response),
    # so the key must be CHECKBOX. Switch to SCORE here when the frontend moves to v3.
    integration_type  = "CHECKBOX"
    allow_all_domains = length(local.recaptcha_allowed_domains) == 0
    allowed_domains   = local.recaptcha_allowed_domains
  }

  lifecycle {
    precondition {
      condition     = !var.enable_recaptcha || length(local.recaptcha_allowed_domains) > 0
      error_message = "enable_recaptcha requires at least one domain in web_domain_name, api_domain_name or recaptcha_additional_domains, otherwise the key would accept requests from any domain."
    }
  }
}

data "google_client_config" "default" {}

# The provider exposes no legacy secret key, so it is fetched from the
# projects.keys.retrieveLegacySecretKey REST method. That secret is what
# CARE's backend uses against https://www.google.com/recaptcha/api/siteverify.
# Only fetched when the secrets are actually consumed, so environments with
# reCAPTCHA disabled do not need the extra permission on every plan.
data "http" "recaptcha_legacy_secret" {
  count = var.enable_recaptcha ? 1 : 0

  url = "https://recaptchaenterprise.googleapis.com/v1/projects/${var.project_id}/keys/${google_recaptcha_enterprise_key.care.name}:retrieveLegacySecretKey"

  request_headers = {
    Authorization = join(" ", ["Bearer", data.google_client_config.default.access_token])
  }

  retry {
    attempts = 2
  }

  request_timeout_ms = 10000

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "retrieveLegacySecretKey returned HTTP ${self.status_code}. The principal applying this module needs recaptchaenterprise.keys.retrievelegacysecretkey. Response: ${self.response_body}"
    }
  }
}
