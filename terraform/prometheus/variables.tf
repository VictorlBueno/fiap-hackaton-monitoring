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