locals {
  owasp_rules = var.enable_cloud_armor ? {
    sqli             = { priority = 1000, rule = "sqli-v33-stable" }
    xss              = { priority = 1001, rule = "xss-v33-stable" }
    rce              = { priority = 1002, rule = "rce-v33-stable" }
    lfi              = { priority = 1003, rule = "lfi-v33-stable" }
    scannerdetection = { priority = 1004, rule = "scannerdetection-v33-stable" }
  } : {}
}

resource "google_compute_region_ssl_policy" "care_ssl_policy" {
  count           = var.enable_cloud_armor ? 1 : 0
  name            = "care-ssl-policy-${var.app}-${var.environment}"
  region          = var.region
  project         = var.project_id
  min_tls_version = "TLS_1_2"
  profile         = "MODERN"
}

resource "google_compute_region_security_policy" "care" {
  count       = var.enable_cloud_armor ? 1 : 0
  provider    = google-beta
  name        = "care-security-policy-${var.app}-${var.environment}"
  description = "Regional Cloud Armor security policy for CARE"
  project     = var.project_id
  region      = var.region
  type        = "CLOUD_ARMOR"
}

resource "google_compute_region_security_policy_rule" "default_allow" {
  count           = var.enable_cloud_armor ? 1 : 0
  provider        = google-beta
  project         = var.project_id
  region          = var.region
  security_policy = google_compute_region_security_policy.care[0].name
  action          = "allow"
  priority        = 2147483647
  description     = "Default allow rule"

  match {
    versioned_expr = "SRC_IPS_V1"
    config { src_ip_ranges = ["*"] }
  }
}

resource "google_compute_region_security_policy_rule" "acme_challenge_allow" {
  count           = var.enable_cloud_armor ? 1 : 0
  provider        = google-beta
  project         = var.project_id
  region          = var.region
  security_policy = google_compute_region_security_policy.care[0].name
  action          = "allow"
  priority        = 800
  description     = "Allow ACME HTTP-01 challenge requests for Let's Encrypt certificate validation"

  match {
    expr { expression = "request.path.matches('/.well-known/acme-challenge/.*')" }
  }
}

resource "google_compute_region_security_policy_rule" "geo_block" {
  count           = var.enable_cloud_armor ? 1 : 0
  provider        = google-beta
  project         = var.project_id
  region          = var.region
  security_policy = google_compute_region_security_policy.care[0].name
  action          = "deny(403)"
  priority        = 900
  description     = "Block requests from outside India"

  match {
    expr { expression = "origin.region_code != 'IN'" }
  }
}
resource "google_compute_region_security_policy_rule" "owasp" {
  for_each = local.owasp_rules

  provider        = google-beta
  project         = var.project_id
  region          = var.region
  security_policy = google_compute_region_security_policy.care[0].name
  action          = "deny(403)"
  priority        = each.value.priority
  description     = "Block ${each.value.rule}"

  match {
    expr { expression = "evaluatePreconfiguredWaf('${each.value.rule}', {'sensitivity': 1})" }
  }
}
