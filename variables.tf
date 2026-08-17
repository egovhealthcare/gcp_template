variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_number" {
  description = "GCP project number"
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "backend_bucket" {
  description = "GCS bucket for OpenTofu state backend"
  type        = string
  default     = ""
}

variable "org" {
  description = "Organization prefix"
  type        = string
  default     = "ohn"
}

variable "app" {
  description = "Application short name"
  type        = string
}

variable "environment" {
  description = "Environment name (for example staging, production)"
  type        = string
  default     = "prod"
}

variable "zones" {
  description = "Zones used in the region"
  type        = list(string)
  default     = []
}

variable "zone" {
  description = "Primary zone"
  type        = string
  default     = null
}

variable "node_pools" {
  description = "GKE node pool definitions"
  type        = any
  default     = []
}

variable "database_subnets" {
  description = "Database subnet CIDR"
  type        = string
  default     = null
}

variable "gke_subnets" {
  description = "GKE subnet CIDR"
  type        = string
  default     = null
}

variable "gke_pods_range" {
  description = "GKE pods secondary CIDR"
  type        = string
  default     = null
}

variable "gke_services_range" {
  description = "GKE services secondary CIDR"
  type        = string
  default     = null
}

variable "proxy_only_subnet_cidr" {
  description = "Proxy-only subnet CIDR"
  type        = string
  default     = null
}

variable "cloudsql_tier" {
  description = "Cloud SQL primary instance tier"
  type        = string
  default     = "db-custom-2-3840"
}

variable "cloudsql_availability_type" {
  description = "Cloud SQL primary availability type: REGIONAL (HA, with standby in another zone) or ZONAL (no HA, single zone)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.cloudsql_availability_type)
    error_message = "cloudsql_availability_type must be either \"REGIONAL\" or \"ZONAL\"."
  }
}

variable "cloudsql_disk_size" {
  description = "Cloud SQL disk size"
  type        = any
  default     = 10
}

variable "cloudsql_read_replica_count" {
  description = "Cloud SQL read replica count"
  type        = any
  default     = 1
}

variable "cloudsql_read_replica_tier" {
  description = "Cloud SQL read replica tier"
  type        = string
  default     = "db-custom-1-3840"
}

variable "metabase_cloudsql_tier" {
  description = "Cloud SQL tier for Metabase"
  type        = string
  default     = "db-f1-micro"
}

variable "metabase_cloudsql_disk_size" {
  description = "Cloud SQL disk size for Metabase"
  type        = any
  default     = 10
}

variable "service_account_email" {
  description = "Service account email used by infra/KMS resources"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a valid GCP service account email (ending in .gserviceaccount.com)."
  }
}

variable "jumphost_ssh_keys" {
  description = "SSH keys for jumphost access"
  type        = any
  default     = []
}

variable "web_domain_name" {
  description = "Frontend domains"
  type        = list(string)
  default     = []
}

variable "api_domain_name" {
  description = "API domains"
  type        = list(string)
  default     = []
}

variable "metabase_domain_name" {
  description = "Metabase domains"
  type        = list(string)
  default     = []
}

variable "dicom_domain_name" {
  description = "DICOM domains"
  type        = list(string)
  default     = []
}

variable "enable_dns_zone" {
  description = "Enable Cloud DNS zone resources"
  type        = bool
  default     = false
}

variable "dns_zone_domain" {
  description = "Base DNS domain for managed zone"
  type        = string
  default     = ""
}

variable "enable_github_wif" {
  description = "Enable GitHub WIF resources"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository allowed for WIF (owner/repo)"
  type        = string
  default     = ""
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor resources/integration"
  type        = bool
  default     = false
}

variable "enable_dicom" {
  description = "Enable DICOM stack"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_dicom == false || length(var.dicom_domain_name) > 0
    error_message = "dicom_domain_name must contain at least one domain when enable_dicom is true."
  }
}

variable "enable_legacy_ingress" {
  description = "Enable legacy global ingress resources"
  type        = bool
  default     = false
}

variable "enable_jumphost" {
  description = "Enable jumphost VM and related resources"
  type        = bool
  default     = true
}

variable "jwks_base64" {
  description = "Base64-encoded JWKS payload"
  type        = string
  default     = ""
}

variable "helm_config" {
  description = "Helm image/release configuration per service."
  type = object({
    care_backend = object({
      repository                  = string
      tag                         = string
      api_replica_count           = optional(number, 2)
      celery_worker_replica_count                    = optional(number, 1)
      celery_worker_autoscaling_enabled              = optional(bool, false)
      celery_worker_autoscaling_min_replicas         = optional(number, 2)
      celery_worker_autoscaling_max_replicas         = optional(number, 6)
      celery_worker_autoscaling_target_cpu           = optional(number, 80)
    })
    care_frontend = object({
      repository = string
      tag        = string
    })
    metabase = optional(object({
      repository = optional(string, "metabase/metabase")
      tag        = optional(string, "v0.61.x")
    }), {})
    redis = optional(object({
      repository = optional(string, "redis")
      tag        = optional(string, "8-alpine")
    }), {})
  })
}

variable "additional_secrets" {
  description = "Additional key/value entries for Kubernetes Secret"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "additional_config_map_data" {
  description = "Additional key/value entries for Kubernetes ConfigMap"
  type        = map(string)
  default     = {}
}

variable "additional_plugs" {
  description = "JSON-encoded plugin manifest for the care backend. Overwritten by the deploy pipeline from build/care/care.env on every run."
  type        = string
  default     = "[]"
}

variable "namespace_name" {
  description = "Override for Kubernetes namespace name"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Override for GKE cluster name"
  type        = string
  default     = null
}

variable "vpc_network_name" {
  description = "Override for VPC network name"
  type        = string
  default     = null
}

variable "database_subnet_name" {
  description = "Override for database subnet name"
  type        = string
  default     = null
}

variable "gke_subnet_name" {
  description = "Override for GKE subnet name"
  type        = string
  default     = null
}

variable "pods_range_name" {
  description = "Override for GKE pods secondary range name"
  type        = string
  default     = null
}

variable "services_range_name" {
  description = "Override for GKE services secondary range name"
  type        = string
  default     = null
}

variable "gateway_ip_name" {
  description = "Override for gateway static IP name"
  type        = string
  default     = null
}

variable "legacy_ingress_ip_name" {
  description = "Override for legacy ingress static IP name"
  type        = string
  default     = null
}

variable "legacy_fe_ip_name" {
  description = "Override for legacy frontend static IP name"
  type        = string
  default     = null
}

variable "flow_logs_bucket" {
  description = "Override for VPC flow logs bucket name"
  type        = string
  default     = null
}

variable "cloudsql_private_ip_name" {
  description = "Override for Cloud SQL private IP allocation name"
  type        = string
  default     = null
}

variable "nat_ip_address_name" {
  description = "Override for NAT static IP name"
  type        = string
  default     = null
}

variable "proxy_only_subnet_name" {
  description = "Override name for the regional managed proxy-only subnet. Defaults to proxy-only-subnet-<app>-<environment>. Set this to adopt an existing subnet (e.g. the legacy hardcoded \"proxy-only-subnet\") since subnet names are immutable in GCP."
  type        = string
  default     = null
}

variable "metabase_encryption_secret_key_override" {
  description = "Override for Metabase encryption secret key"
  type        = string
  default     = null
}

variable "snowstorm_deployment_url" {
  description = "Snowstorm FHIR endpoint URL"
  type        = string
  default     = "https://terminology.10bedicu.in/fhir"
}

variable "enable_scribe" {
  description = "Enable AI Scribe stack (Vertex AI service account and configuration)"
  type        = bool
  default     = false
}

variable "scribe_sa_name" {
  description = "Override for the Scribe Vertex AI service account ID. Defaults to gemini-scribe."
  type        = string
  default     = null
}

variable "external_tls_cert" {
  description = "PEM-encoded TLS certificate (e.g. wildcard *.example.org) provided externally"
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.external_tls_cert == null || var.external_tls_cert != ""
    error_message = "external_tls_cert must not be an empty string. Set to null to disable."
  }
}

variable "external_tls_key" {
  description = "PEM-encoded TLS private key for the external certificate"
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = (var.external_tls_cert == null) == (var.external_tls_key == null)
    error_message = "external_tls_cert and external_tls_key must both be set or both be null."
  }
}

variable "external_tls_base_domains" {
  description = "Base domains covered by the external wildcard cert (e.g. [\"example.org\"] for *.example.org). Subdomains of these are excluded from cert-manager issuance."
  type        = list(string)
  default     = []

  validation {
    condition     = var.external_tls_cert == null || length(var.external_tls_base_domains) > 0
    error_message = "external_tls_base_domains must be non-empty when external_tls_cert is provided."
  }
}
