variable "grafana_storage_size" {
  description = "Tamanho do storage para o Grafana"
  type        = string
  default     = "1Gi"
}

variable "grafana_admin_password" {
  description = "Senha do administrador do Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
} 