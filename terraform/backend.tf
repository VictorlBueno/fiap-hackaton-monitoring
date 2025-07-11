terraform {
  backend "s3" {
    bucket = "fiap-hack-terraform-state"
    key    = "monitoring/terraform.tfstate"
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