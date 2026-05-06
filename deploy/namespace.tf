resource "kubernetes_namespace" "care_namespace" {
  metadata {
    name = local.namespace_name
  }
}