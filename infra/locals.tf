locals {
  required_tags = {
    terraform   = "true"
    environment = local.cfg["environment"]
    app         = local.cfg["app"]
    project     = "care"
  }

  common_labels = {
    app         = local.cfg["app"]
    environment = local.cfg["environment"]
    project     = "care"
  }
  tags                 = local.required_tags
  database_subnets     = local.cfg["database_subnets"]
  gke_subnets          = local.cfg["gke_subnets"]
  gke_pods_range       = local.cfg["gke_pods_range"]
  gke_services_range   = local.cfg["gke_services_range"]
  patient_bucket_name  = "${local.cfg["org"]}-${local.cfg["environment"]}-${local.cfg["app"]}-patient"
  facility_bucket_name = "${local.cfg["org"]}-${local.cfg["environment"]}-${local.cfg["app"]}-facility"
  dicom_bucket_name    = "${local.cfg["org"]}-${local.cfg["environment"]}-${local.cfg["app"]}-dicom"
  writer_sa_email      = module.service_accounts.email
  #middleware_sa_email  = module.middleware_archive_service_accounts.email

  cluster_name = coalesce(lookup(local.cfg, "cluster_name", null), "${local.cfg["org"]}-${local.cfg["app"]}-${local.cfg["environment"]}")

  # Network resource name resolution (legacy name support)
  vpc_network_name         = coalesce(lookup(local.cfg, "vpc_network_name", null), "${local.cfg["org"]}-${local.cfg["environment"]}")
  database_subnet_name     = coalesce(lookup(local.cfg, "database_subnet_name", null), "database-${local.cfg["app"]}-${local.cfg["environment"]}")
  gke_subnet_name          = coalesce(lookup(local.cfg, "gke_subnet_name", null), "gke-${local.cfg["app"]}-${local.cfg["environment"]}")
  pods_range_name          = coalesce(lookup(local.cfg, "pods_range_name", null), "gke-pods-range-${local.cfg["app"]}-${local.cfg["environment"]}")
  services_range_name      = coalesce(lookup(local.cfg, "services_range_name", null), "gke-services-range-${local.cfg["app"]}-${local.cfg["environment"]}")
  gateway_ip_name          = coalesce(lookup(local.cfg, "gateway_ip_name", null), "care-pip-${local.cfg["app"]}-${local.cfg["environment"]}")
  legacy_ingress_ip_name   = coalesce(lookup(local.cfg, "legacy_ingress_ip_name", null), "care-pip")
  legacy_fe_ip_name        = coalesce(lookup(local.cfg, "legacy_fe_ip_name", null), "care-fe")
  flow_logs_bucket         = coalesce(lookup(local.cfg, "flow_logs_bucket", null), "${local.cfg["org"]}-${local.cfg["environment"]}-vpc-flow-logs")
  cloudsql_private_ip_name = coalesce(lookup(local.cfg, "cloudsql_private_ip_name", null), "cloudsql-private-ip-${local.cfg["app"]}-${local.cfg["environment"]}")
  nat_ip_address_name      = coalesce(lookup(local.cfg, "nat_ip_address_name", null), "nat-ip-${local.cfg["app"]}-${local.cfg["environment"]}")

  enable_legacy_ingress = lookup(local.cfg, "enable_legacy_ingress", false)

  cors_origins = [for domain in local.cfg["web_domain_name"] : "https://${domain}"]
}
