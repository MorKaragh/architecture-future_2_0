variable "cloud_id" {
  type        = string
  description = "Идентификатор облака (как в yc config / TF_VAR_cloud_id)."
}

variable "folder_id" {
  type        = string
  description = "Каталог, в котором создаётся бакет Object Storage."
}

variable "zone" {
  type        = string
  description = "Зона для провайдера yandex (на бакет не влияет)."
  default     = "ru-central1-a"
}

variable "service_account_id" {
  type        = string
  description = "Сервисный аккаунт: на бакет выдаётся доступ для state; для него же опционально создаётся статический ключ S3."
}

variable "bucket_prefix" {
  type        = string
  description = "Префикс имени бакета, если bucket_name не задан (имя = префикс + '-' + случайный суффикс)."
  default     = "tfstate-future20-task2"
}

variable "bucket_name" {
  type        = string
  description = "Фиксированное имя бакета. Если пустая строка — имя собирается из bucket_prefix и random_id."
  default     = ""
}

variable "create_static_access_key" {
  type        = bool
  description = "Создать статический ключ доступа для service_account_id (секрет попадёт в локальный state bootstrap)."
  default     = true
}

variable "versioning" {
  type        = bool
  description = "Включить версионирование бакета. Для многих ролей (например только storage.editor на каталог) операция даёт 403 — тогда оставьте false или выдайте СА права на управление версионированием (например storage.admin на каталог)."
  default     = false
}
