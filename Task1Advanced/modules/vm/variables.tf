variable "vm_name" {
  type        = string
  description = "Имя виртуальной машины и префикс для связанных ресурсов."
}

variable "zone" {
  type        = string
  description = "Зона размещения ВМ и дополнительного диска (должна соответствовать зоне подсети)."
}

variable "cores" {
  type        = number
  description = "Количество vCPU."
}

variable "memory" {
  type        = number
  description = "Объём RAM, ГБ."
}

variable "subnet_id" {
  type        = string
  description = "Идентификатор подсети для сетевого интерфейса."
}

variable "ssh_public_key" {
  type        = string
  description = "Публичный SSH-ключ (строка вида ssh-ed25519 ... или ssh-rsa ...)."
  sensitive   = true
}

variable "ssh_user" {
  type        = string
  description = "Учётная запись в metadata ssh-keys."
  default     = "ubuntu"
}

variable "attach_disk_size" {
  type        = number
  description = "Размер подключаемого диска, ГБ."
}

variable "attach_disk_type" {
  type        = string
  description = "Тип подключаемого диска (network-hdd, network-ssd и т.д.)."
  default     = "network-hdd"
}

variable "boot_disk_size" {
  type        = number
  description = "Размер загрузочного диска, ГБ."
  default     = 20
}

variable "image_family" {
  type        = string
  description = "Семейство образа для загрузочного диска."
  default     = "ubuntu-2204-lts"
}

variable "enable_nat" {
  type        = bool
  description = "Назначать публичный IPv4 для доступа по SSH извне."
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Метки ресурсов."
  default     = {}
}

variable "platform_id" {
  type        = string
  description = "Платформа vCPU."
  default     = "standard-v3"
}
