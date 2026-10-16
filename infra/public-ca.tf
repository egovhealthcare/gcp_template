# The EAB key expires 7 days after creation, so the account is registered in
# the same apply and cert-manager reuses its key instead of the EAB key.
#
# The account only changes when the account key does. To start over (or if a
# registration failed and the EAB key has since expired), run:
#   tofu apply -replace='tls_private_key.acme_account[0]'

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

# Destroying this deactivates the account at Google
resource "acme_registration" "google" {
  count = local.use_google_public_ca ? 1 : 0

  account_key_pem = tls_private_key.acme_account[0].private_key_pem
  email_address   = var.acme_email

  external_account_binding {
    key_id      = google_public_ca_external_account_key.acme[0].key_id
    hmac_base64 = google_public_ca_external_account_key.acme[0].b64url_mac_key
  }

  lifecycle {
    # Every argument forces a replacement, which deactivates the account and
    # cannot re-register with the same key. cert-manager updates the contact
    # email on the existing account from the ClusterIssuer instead.
    ignore_changes = [email_address, external_account_binding]
  }
}
