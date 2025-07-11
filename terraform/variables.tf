variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "fiap-hack"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "production"
}

variable "grafana_admin_password" {
  description = "Senha do admin do Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "prometheus_retention_days" {
  description = "Dias de retenção dos dados do Prometheus"
  type        = number
  default     = 7
}

variable "prometheus_storage_size" {
  description = "Tamanho do storage do Prometheus"
  type        = string
  default     = "2Gi"
}

variable "grafana_storage_size" {
  description = "Tamanho do storage do Grafana"
  type        = string
  default     = "1Gi"
} 