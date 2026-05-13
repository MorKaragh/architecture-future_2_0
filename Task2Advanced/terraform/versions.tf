terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }

  # Параметры backend (bucket, key, endpoint) передаются через
  # terraform init -backend-config=... см. backend.config.example.hcl
  backend "s3" {}
}
