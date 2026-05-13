provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "random_id" "suffix" {
  count       = var.bucket_name == "" ? 1 : 0
  byte_length = 4
}

locals {
  bucket_id = var.bucket_name != "" ? var.bucket_name : "${var.bucket_prefix}-${random_id.suffix[0].hex}"
}

resource "yandex_storage_bucket" "tf_state" {
  bucket        = local.bucket_id
  force_destroy = true

  # Блок versioning вызывает отдельный S3 API-вызов; при enabled = true часто нужны
  # права шире storage.editor. По умолчанию блок не создаём (var.versioning = false).
  dynamic "versioning" {
    for_each = var.versioning ? [1] : []
    content {
      enabled = true
    }
  }
}

# Отдельный IAM binding на бакет (storage_bucket_iam_binding) в Yandex Cloud часто
# требует storage.admin у вызывающего токена и даёт PermissionDenied при одном только
# storage.editor на каталог. Роль storage.editor на каталог уже позволяет
# читать/писать объекты в бакетах каталога — отдельная привязка не нужна.

resource "yandex_iam_service_account_static_access_key" "s3" {
  count              = var.create_static_access_key ? 1 : 0
  service_account_id = var.service_account_id
  description        = "Terraform remote state (bootstrap Task2Advanced)"
}
