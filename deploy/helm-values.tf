locals {
  care_backend_secret_checksum = nonsensitive(sha256(jsonencode(local.secret_data)))
  care_backend_config_checksum = sha256(jsonencode(local.config_map_data))
  metabase_secret_checksum     = nonsensitive(sha256(jsonencode(local.metabase_secret_data)))
  dcm4chee_secret_checksum     = var.enable_dicom ? nonsensitive(sha256(jsonencode(local.dicom_secret_data))) : ""

  # External wildcard TLS: filter out domains already covered by the wildcard
  all_domains = concat(var.web_domain_name, var.api_domain_name, var.metabase_domain_name, var.dicom_domain_name)

  # Domains that still need cert-manager (i.e. NOT covered by the wildcard)
  # Example: wildcard is *.example.org → "app.example.org" is covered, "dicom.other.org" is not
  certmanager_domains = local.use_external_tls ? [
    for domain in local.all_domains : domain
    if !anytrue([for base in var.external_tls_base_domains : endswith(domain, ".${base}") || domain == base])
  ] : local.all_domains

  # Gateway TLS: list of K8s Secret names to attach to the HTTPS listener
  gateway_certificate_refs = compact([
    local.use_external_tls ? local.external_tls_secret_name : "",
    length(local.certmanager_domains) > 0 ? local.certmanager_tls_secret_name : "",
  ])

  gateway_values = {
    gateway = {
      name             = local.gateway_name
      gatewayClassName = local.common_helm_values.global.gateway.gatewayClassName
      address = {
        enabled = true
        type    = "NamedAddress"
        value   = data.terraform_remote_state.infra.outputs.gateway_ip_name
      }
      httpsListener = {
        enabled = true
        tls = {
          tlsMode         = "certmanager"
          certificateRefs = [for name in local.gateway_certificate_refs : { name = name }]
        }
      }
      gatewayPolicy = {
        enabled        = var.enable_cloud_armor
        securityPolicy = data.terraform_remote_state.infra.outputs.security_policy_name
        sslPolicy      = data.terraform_remote_state.infra.outputs.ssl_policy_name
      }
    }
    certmanager = {
      enabled = true
      clusterIssuer = {
        name                 = "letsencrypt-prod"
        server               = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretName = "letsencrypt-prod-account-key"
        solver = {
          httpSectionName = "http"
        }
      }
      certificate = {
        name       = "${var.org}-${var.app}-${var.environment}-gateway-cert"
        secretName = local.certmanager_tls_secret_name
        dnsNames   = local.certmanager_domains
      }
    }
  }

  redis_values = {
    replicaCount = 1
    image = {
      repository = var.helm_config.redis.repository
      tag        = var.helm_config.redis.tag
    }
  }

  metabase_values = {
    replicaCount = 1
    image = {
      repository = var.helm_config.metabase.repository
      tag        = var.helm_config.metabase.tag
    }
    httpRoute = {
      hostnames = var.metabase_domain_name
    }
    podAnnotations = {
      "checksum/external-secret" = local.metabase_secret_checksum
    }
    envFromSecret = [
      { name = kubernetes_secret.metabase.metadata[0].name }
    ]
  }

  care_backend_values = {
    image = {
      repository = var.helm_config.care_backend.repository
      tag        = var.helm_config.care_backend.tag
    }
    api = {
      replicaCount = 2
      podAnnotations = {
        "checksum/external-secret" = local.care_backend_secret_checksum
        "checksum/external-config" = local.care_backend_config_checksum
      }
    }
    celeryWorker = {
      podAnnotations = {
        "checksum/external-secret" = local.care_backend_secret_checksum
        "checksum/external-config" = local.care_backend_config_checksum
      }
    }
    celeryBeat = {
      podAnnotations = {
        "checksum/external-secret" = local.care_backend_secret_checksum
        "checksum/external-config" = local.care_backend_config_checksum
      }
    }
    podAnnotations = {
      "checksum/external-secret" = local.care_backend_secret_checksum
      "checksum/external-config" = local.care_backend_config_checksum
    }
    configMap = {
      enabled = true
      data    = local.config_map_data
    }
    httpRoute = {
      hostnames = var.api_domain_name
    }
    envFromSecret = [
      { name = kubernetes_secret.care_backend.metadata[0].name }
    ]
  }

  care_frontend_values = {
    replicaCount = 2
    image = {
      repository = var.helm_config.care_frontend.repository
      tag        = var.helm_config.care_frontend.tag
    }
    httpRoute = {
      hostnames = var.web_domain_name
    }
  }

  dcm4chee_values = {
    dicomBaseUrl = var.enable_dicom ? "https://${var.dicom_domain_name[0]}" : ""
    podAnnotations = {
      "checksum/external-secret" = local.dcm4chee_secret_checksum
    }
    nginx = {
      authBackendUrl = "http://care-backend-care-be.${local.namespace_name}.svc.cluster.local:${local.care_backend_port}/api/care_radiology/dicom/authenticate/"
    }
    httpRoute = {
      hostnames = var.dicom_domain_name
    }
    envFromSecret = var.enable_dicom ? [
      { name = kubernetes_secret.dcm4chee[0].metadata[0].name }
    ] : []
  }

}
