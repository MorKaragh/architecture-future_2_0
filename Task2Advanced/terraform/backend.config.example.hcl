# Локально: скопируйте в backend.auto.hcl (файл в .gitignore) или используйте
# terraform init -backend-config=путь/к/файлу.hcl
#
# Yandex Object Storage (S3 API)
bucket = "имя-бакета-для-state"
key    = "task2/terraform.tfstate"
region = "ru-central1"

endpoints = { s3 = "https://storage.yandexcloud.net" }

skip_region_validation      = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_s3_checksum            = true

# MinIO: замените значение `s3` в `endpoints` и при необходимости добавьте use_path_style = true
