output "bucket_name" {
  description = "Имя бакета для TF_STATE_BUCKET и backend."
  value       = yandex_storage_bucket.tf_state.id
}

output "recommended_state_key" {
  description = "Рекомендуемый ключ объекта state для backend."
  value       = "task2/terraform.tfstate"
}

output "s3_access_key_id" {
  description = "Идентификатор статического ключа (YC_S3_ACCESS_KEY_ID / AWS_ACCESS_KEY_ID). Пусто, если create_static_access_key = false."
  value       = try(yandex_iam_service_account_static_access_key.s3[0].access_key, null)
  sensitive   = true
}

output "s3_secret_access_key" {
  description = "Секрет статического ключа. Только из вывода apply; храните в секрет-хранилище."
  value       = try(yandex_iam_service_account_static_access_key.s3[0].secret_key, null)
  sensitive   = true
}
