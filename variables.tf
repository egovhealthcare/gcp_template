variable "project_id" {
  description = "GCP project ID (bootstrap variable, set via TF_VAR_project_id)"
  type        = string
}

variable "region" {
  description = "GCP region (bootstrap variable, set via TF_VAR_region)"
  type        = string
}

variable "env_name" {
  description = "Environment name used to fetch config from Secret Manager (tofu-env-{env_name}). Set via TF_VAR_env_name."
  type        = string
}

variable "backend_bucket" {
  description = "GCS bucket for Terraform state backend (set via TF_VAR_backend_bucket)"
  type        = string
}