output "django_secret_key" {
  description = "Django secret key for the application"
  value       = random_password.django_secret_key.result
  sensitive   = true
}

output "django_admin_password" {
  description = "Django admin password"
  value       = random_password.django_admin_password.result
  sensitive   = true
}

output "metabase_encryption_secret_key" {
  description = "Metabase encryption secret key"
  value       = random_password.metabase_encryption_secret_key.result
  sensitive   = true
}
