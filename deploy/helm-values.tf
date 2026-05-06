locals {
  generated_values_dir = "${path.module}/generated_values"

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
          tlsMode    = "certmanager"
          secretName = local.certmanager_tls_secret_name
        }
      }
      gatewayPolicy = {
        enabled        = lookup(local.cfg, "enable_cloud_armor", false)
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
        name       = "${local.cfg["org"]}-${local.cfg["app"]}-${local.cfg["environment"]}-gateway-cert"
        secretName = local.certmanager_tls_secret_name
        dnsNames   = concat(local.cfg["web_domain_name"], local.cfg["api_domain_name"], local.cfg["metabase_domain_name"], lookup(local.cfg, "dicom_domain_name", []))
      }
    }
  }

  redis_values = {
    replicaCount = 1
    image = {
      repository = local.cfg["helm_config"]["redis"]["repository"]
      tag        = local.cfg["helm_config"]["redis"]["tag"]
    }
  }

  metabase_values = {
    replicaCount = 1
    image = {
      repository = local.cfg["helm_config"]["metabase"]["repository"]
      tag        = local.cfg["helm_config"]["metabase"]["tag"]
    }
    httpRoute = {
      hostnames = local.cfg["metabase_domain_name"]
    }
    envFromSecret = [
      { name = kubernetes_secret.metabase.metadata[0].name }
    ]
  }

  care_backend_values = {
    image = {
      repository = local.cfg["helm_config"]["care_backend"]["repository"]
      tag        = local.cfg["helm_config"]["care_backend"]["tag"]
    }
    api = {
      replicaCount = 2
    }
    configMap = {
      enabled = true
      data    = local.config_map_data
    }
    httpRoute = {
      hostnames = local.cfg["api_domain_name"]
    }
    envFromSecret = [
      { name = kubernetes_secret.care_backend.metadata[0].name }
    ]
  }

  care_frontend_values = {
    replicaCount = 2
    image = {
      repository = local.cfg["helm_config"]["care_frontend"]["repository"]
      tag        = local.cfg["helm_config"]["care_frontend"]["tag"]
    }
    httpRoute = {
      hostnames = local.cfg["web_domain_name"]
    }
  }

  dcm4chee_values = {
    dicomBaseUrl = lookup(local.cfg, "enable_dicom", false) ? "https://${local.cfg["dicom_domain_name"][0]}" : ""
    nginx = {
      authBackendUrl = "http://care-backend-care-be.${local.namespace_name}.svc.cluster.local:${local.care_backend_port}/api/care_radiology/dicom/authenticate/"
    }
    httpRoute = {
      hostnames = lookup(local.cfg, "dicom_domain_name", [])
    }
    envFromSecret = lookup(local.cfg, "enable_dicom", false) ? [
      { name = kubernetes_secret.dcm4chee[0].metadata[0].name }
    ] : []
  }

}

resource "local_file" "common_values" {
  filename        = "${local.generated_values_dir}/common/values.yaml"
  content         = yamlencode(local.common_helm_values)
  file_permission = "0644"
}

resource "local_file" "gateway_values" {
  filename        = "${local.generated_values_dir}/gateway/values.yaml"
  content         = yamlencode(local.gateway_values)
  file_permission = "0644"
}

resource "local_file" "redis_values" {
  filename        = "${local.generated_values_dir}/redis/values.yaml"
  content         = yamlencode(local.redis_values)
  file_permission = "0644"
}

resource "local_file" "metabase_values" {
  filename        = "${local.generated_values_dir}/metabase/values.yaml"
  content         = yamlencode(local.metabase_values)
  file_permission = "0644"
}

resource "local_file" "care_backend_values" {
  filename        = "${local.generated_values_dir}/care_be/values.yaml"
  content         = yamlencode(local.care_backend_values)
  file_permission = "0644"
}

resource "local_file" "care_frontend_values" {
  filename        = "${local.generated_values_dir}/care_fe/values.yaml"
  content         = yamlencode(local.care_frontend_values)
  file_permission = "0644"
}

resource "local_file" "dcm4chee_values" {
  count           = lookup(local.cfg, "enable_dicom", false) ? 1 : 0
  filename        = "${local.generated_values_dir}/dcm4chee/values.yaml"
  content         = yamlencode(local.dcm4chee_values)
  file_permission = "0644"
}