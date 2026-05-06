module "dns_zone_tofu" {
  count       = lookup(local.cfg, "enable_dns_zone", false) ? 1 : 0
  source      = "terraform-google-modules/cloud-dns/google"
  version     = "~> 6.0"
  project_id  = var.project_id
  name        = "${local.cfg["org"]}-${local.cfg["app"]}-${local.cfg["environment"]}"
  domain      = "${local.cfg["dns_zone_domain"]}."
  description = "Managed zone for ${local.cfg["dns_zone_domain"]}"
  labels = {
    billing     = "cloud-cdn"
    environment = local.cfg["environment"]
    app         = local.cfg["app"]
  }
  type = "public"

  depends_on = [module.project_services]
}
