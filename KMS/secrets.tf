resource "random_password" "django_secret_key" {
  length  = 32
  special = true
}

resource "random_password" "django_admin_password" {
  length  = 16
  special = true
}

resource "random_password" "metabase_encryption_secret_key" {
  length  = 32
  special = false
}
