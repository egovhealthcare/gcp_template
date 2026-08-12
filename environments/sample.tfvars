# -----------------------------------------------------------------------------
# Core environment identity
# -----------------------------------------------------------------------------
region         = "asia-south1"
project_id     = "example-project-id"
project_number = "123456789012"

# GKE multi-zone placement.
zones = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
zone  = "asia-south1-a"

# Naming inputs used across resources.
org         = "example-org"
app         = "example-app"
environment = "staging"

# Public DNS names (arrays are required by module variable types).
web_domain_name      = ["app.example.org"]
api_domain_name      = ["api.example.org"]
metabase_domain_name = ["metabase.example.org"]
dicom_domain_name    = ["dicom.example.org"]

# Set enable_dns_zone=true only if Terraform should create/manage the DNS zone.
enable_dns_zone = false
dns_zone_domain = "example.org"

# GKE node pool defaults (can add more pool objects if needed).
node_pools = [
  {
    name           = "default"
    machine_type   = "e2-standard-2"
    min_count      = 1
    max_count      = 2
    preemptible    = false
    disk_size_gb   = 100
    node_locations = "asia-south1-a,asia-south1-b"
  },
]

# Network CIDR ranges.
database_subnets       = "10.0.21.0/24"
gke_subnets            = "10.20.0.0/16"
gke_pods_range         = "10.21.0.0/16"
gke_services_range     = "10.22.0.0/20"
proxy_only_subnet_cidr = "10.129.0.0/23"

# Base64-encoded JWKS JSON string used by backend auth.
jwks_base64 = "CHANGE_ME_BASE64_JWKS"

# Cloud SQL sizing.
# Use numbers (not quoted strings) for size and replica count.
cloudsql_disk_size          = 10
cloudsql_read_replica_count = 1
cloudsql_tier               = "db-custom-2-3840"
cloudsql_read_replica_tier  = "db-custom-1-3840"
metabase_cloudsql_tier      = "db-f1-micro"
metabase_cloudsql_disk_size = 10

# Feature toggles.
enable_dicom          = false
enable_legacy_ingress = false
enable_cloud_armor    = true
enable_github_wif     = false
enable_scribe         = false
enable_jumphost       = true
enable_recaptcha      = false

# reCAPTCHA. The key is always provisioned by infra/; enable_recaptcha only controls
# whether the site/secret keys are injected into the CARE backend secret.
# recaptcha_additional_domains is appended to web_domain_name and api_domain_name.
recaptcha_additional_domains = []

# Service account used by workloads/automation where applicable.
service_account_email = "iac-tofu@example-project-id.iam.gserviceaccount.com"

# SSH public keys for jump host access.
jumphost_ssh_keys = [
  {
    user = "ubuntu"
    key  = "ssh-ed25519 AAAA... replace-with-public-key"
  },
]

# Helm image/release configuration consumed by deploy module.
helm_config = {
  care_backend = {
    repository = "asia-south1-docker.pkg.dev/example-project/staging/care"
    tag        = "latest"
  }
  care_frontend = {
    repository = "asia-south1-docker.pkg.dev/example-project/staging/care_fe"
    tag        = "latest"
  }
  metabase = {
    repository = "metabase/metabase"
    tag        = "v0.57.x"
  }
  redis = {
    repository = "redis"
    tag        = "8-alpine"
  }
}

# GitHub repository allowed to use Workload Identity Federation (owner/repo).
github_repo = "example-org/example-repo"

# Optional application-specific settings.
snowstorm_deployment_url                = "https://terminology.example.org/fhir"
metabase_encryption_secret_key_override = null

# Extra secrets injected into Kubernetes secrets.
additional_secrets = {
  EXAMPLE_API_KEY = "CHANGE_ME"
}

# Extra non-secret config injected into ConfigMaps.
additional_config_map_data = {
  EXAMPLE_FEATURE_FLAG = "true"
}

# Optional name overrides to preserve legacy resource names during migration.
# Set to null (where supported) to allow auto-generated naming conventions.
cluster_name             = "example-app-cluster-staging"
namespace_name           = "care-staging"
vpc_network_name         = "example-org-staging"
database_subnet_name     = "database"
gke_subnet_name          = "gke"
pods_range_name          = "gke-pods-range"
services_range_name      = "gke-services-range"
gateway_ip_name          = "care-pip-example-app-staging"
legacy_ingress_ip_name   = "care-pip"
legacy_fe_ip_name        = "care-fe"
flow_logs_bucket         = "example-org-staging-vpc-flow-logs"
cloudsql_private_ip_name = "cloudsql-private-ip"
nat_ip_address_name      = "nat-ip-example-app-staging"

# External wildcard TLS certificate (optional).
# When provided, the Gateway uses this cert for domains matching the base domains.
# cert-manager still issues certs for domains NOT covered by the wildcard.
# external_tls_cert         = file("path/to/wildcard.pem")
# external_tls_key          = file("path/to/wildcard.key")
# external_tls_base_domains = ["example.org"]
