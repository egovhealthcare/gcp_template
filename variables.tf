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
  default     = "us-central1"
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
  default     = null
}

variable "cloudsql_disk_size" {
  description = "Cloud SQL disk size"
  type        = any
  default     = null
}

variable "cloudsql_read_replica_count" {
  description = "Cloud SQL read replica count"
  type        = any
  default     = 0
}

variable "cloudsql_read_replica_tier" {
  description = "Cloud SQL read replica tier"
  type        = string
  default     = null
}

variable "metabase_cloudsql_tier" {
  description = "Cloud SQL tier for Metabase"
  type        = string
  default     = null
}

variable "metabase_cloudsql_disk_size" {
  description = "Cloud SQL disk size for Metabase"
  type        = any
  default     = null
}

variable "service_account_email" {
  description = "Service account email used by infra/KMS resources"
  type        = string
  default     = null
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
}

variable "enable_legacy_ingress" {
  description = "Enable legacy global ingress resources"
  type        = bool
  default     = false
}

variable "jwks_base64" {
  description = "Base64-encoded JWKS payload"
  type        = string
  default     = ""
}

variable "helm_config" {
  description = "Helm image/release configuration per service"
  type        = map(map(string))
  default     = {}
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
