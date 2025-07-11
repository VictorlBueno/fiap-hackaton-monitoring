terraform {
  backend "s3" {
    bucket = "fiap-hack-terraform-state"
    key    = "monitoring/grafana/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ConfigMap do Grafana
resource "kubernetes_config_map" "grafana_config" {
  metadata {
    name      = "grafana-config"
    namespace = "monitoring"
  }

  data = {
    "grafana.ini" = <<-EOT
      [server]
      http_port = 3000
      domain = localhost
      
      [security]
      admin_user = admin
      admin_password = admin123
      
      [users]
      allow_sign_up = false
      
      [auth.anonymous]
      enabled = false
      
      [database]
      type = sqlite3
      path = /var/lib/grafana/grafana.db
      
      [session]
      provider = file
      provider_config = sessions
      
      [log]
      mode = console
      level = info
    EOT
  }
}

# ConfigMap para datasources
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = "monitoring"
  }

  data = {
    "datasources.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name  = "Prometheus"
          type  = "prometheus"
          url   = "http://prometheus-service.monitoring.svc.cluster.local:9090"
          access = "proxy"
          isDefault = true
        }
      ]
    })
  }
}

# PersistentVolumeClaim para Grafana
resource "kubernetes_persistent_volume_claim" "grafana_pvc" {
  metadata {
    name      = "grafana-pvc"
    namespace = "monitoring"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = "fiap-hack-gp2"
  }
}

# Deployment do Grafana
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        security_context {
          fs_group = 472
          supplemental_groups = [472]
        }
        
        init_container {
          name  = "init-grafana-permissions"
          image = "busybox:1.35"
          command = ["sh", "-c", "chown -R 472:472 /var/lib/grafana"]
          
          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }
          
          security_context {
            run_as_user = 0
          }
        }
        
        container {
          name  = "grafana"
          image = "grafana/grafana:10.0.0"

          port {
            container_port = 3000
          }
          
          security_context {
            run_as_user = 472
            run_as_group = 472
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "admin123"
          }

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          volume_mount {
            name       = "grafana-config"
            mount_path = "/etc/grafana/grafana.ini"
            sub_path   = "grafana.ini"
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "grafana-config"
          config_map {
            name = kubernetes_config_map.grafana_config.metadata[0].name
          }
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }

        volume {
          name = "grafana-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.grafana_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Service do Grafana (ClusterIP)
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana-service"
    namespace = "monitoring"
    labels = {
      app = "grafana"
    }
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Service do Grafana (LoadBalancer para acesso externo)
resource "kubernetes_service" "grafana_loadbalancer" {
  metadata {
    name      = "grafana-loadbalancer"
    namespace = "monitoring"
    labels = {
      app = "grafana"
    }
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 80
      target_port = 3000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

# Outputs
output "grafana_namespace" {
  value = "monitoring"
}

output "grafana_service_name" {
  value = kubernetes_service.grafana.metadata[0].name
}

output "grafana_loadbalancer_name" {
  value = kubernetes_service.grafana_loadbalancer.metadata[0].name
}

output "grafana_deployment_name" {
  value = kubernetes_deployment.grafana.metadata[0].name
} 