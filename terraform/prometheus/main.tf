terraform {
  backend "s3" {
    bucket = "fiap-hack-terraform-state"
    key    = "monitoring/prometheus/terraform.tfstate"
    region = "us-east-1"
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

# Namespace para monitoramento
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# ConfigMap do Prometheus
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yml" = yamlencode({
      global = {
        scrape_interval     = "15s"
        evaluation_interval = "15s"
      }

      rule_files = []

      scrape_configs = [
        {
          job_name = "prometheus"
          static_configs = [
            {
              targets = ["localhost:9090"]
            }
          ]
        },
        {
          job_name = "video-processor"
          static_configs = [
            {
              targets = ["video-processor-service.video-processor.svc.cluster.local:80"]
            }
          ]
          metrics_path = "/metrics"
          scrape_interval = "10s"
          honor_labels = true
        }
      ]
    })
  }
}

# PersistentVolumeClaim para Prometheus
resource "kubernetes_persistent_volume_claim" "prometheus_pvc" {
  metadata {
    name      = "prometheus-pvc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.prometheus_storage_size
      }
    }
    storage_class_name = "fiap-hack-gp2"
  }
}

# Deployment do Prometheus
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        security_context {
          fs_group = 65534
          run_as_user = 65534
          run_as_group = 65534
        }

        init_container {
          name  = "init-prometheus-db"
          image = "busybox:1.35"
          command = ["sh", "-c", "chown -R 65534:65534 /prometheus && chmod -R 755 /prometheus"]
          
          volume_mount {
            name       = "prometheus-storage"
            mount_path = "/prometheus"
          }

          security_context {
            run_as_user = 0
          }
        }

        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.45.0"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=${var.prometheus_retention_days}d",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--web.enable-lifecycle"
          ]

          port {
            container_port = 9090
          }

          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus"
          }

          volume_mount {
            name       = "prometheus-storage"
            mount_path = "/prometheus"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = 9090
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "prometheus-config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "prometheus-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.prometheus_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Service do Prometheus (ClusterIP)
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus-service"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Outputs
output "prometheus_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_name" {
  value = kubernetes_service.prometheus.metadata[0].name
}

output "prometheus_deployment_name" {
  value = kubernetes_deployment.prometheus.metadata[0].name
} 