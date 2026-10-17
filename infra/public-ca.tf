# The EAB key expires 7 days after creation, so the account is registered in
# the same apply and cert-manager reuses its key instead of the EAB key.

locals {
  use_google_public_ca = var.tls_certificate_issuer == "google"
}

resource "tls_private_key" "acme_account" {
  count = local.use_google_public_ca ? 1 : 0

  # cert-manager only accepts RSA ACME account keys.
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "google_public_ca_external_account_key" "acme" {
  count = local.use_google_public_ca ? 1 : 0

  project  = var.project_id
  location = "global"

  lifecycle {
    # EAB keys are single-use
    replace_triggered_by = [tls_private_key.acme_account]
  }
}

resource "acme_registration" "google" {
  count = local.use_google_public_ca ? 1 : 0

  account_key_pem = tls_private_key.acme_account[0].private_key_pem
  email_address   = var.acme_email

  external_account_binding {
    key_id      = google_public_ca_external_account_key.acme[0].key_id
    hmac_base64 = google_public_ca_external_account_key.acme[0].b64url_mac_key
  }

  lifecycle {
    # Replacing deactivates the account, and its key cannot register again.
    # cert-manager updates the contact email from the ClusterIssuer instead.
    ignore_changes = [email_address, external_account_binding]
  }
}
