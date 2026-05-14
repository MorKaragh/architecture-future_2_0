variable "cloud_id" {
  type        = string
  description = "Идентификатор облака Yandex Cloud."
}

variable "folder_id" {
  type        = string
  description = "Идентификатор каталога."
}

variable "zone" {
  type        = string
  description = "Зона по умолчанию для провайдера."
}

variable "subnet_id" {
  type        = string
  description = "Подсеть для сетевого интерфейса ВМ."
}

variable "ssh_public_key" {
  type        = string
  description = "Публичный SSH-ключ для metadata."
  sensitive   = true
}

variable "vm_name" {
  type        = string
  description = "Имя ВМ."
}

variable "cores" {
  type        = number
  description = "Число vCPU."
}

variable "memory" {
  type        = number
  description = "RAM, ГБ."
}

variable "attach_disk_size" {
  type        = number
  description = "Размер подключаемого диска, ГБ."
}

variable "attach_disk_type" {
  type        = string
  description = "Тип подключаемого диска."
  default     = "network-hdd"
}

variable "boot_disk_size" {
  type        = number
  description = "Размер загрузочного диска, ГБ."
  default     = 20
}

variable "labels" {
  type        = map(string)
  description = "Метки, пробрасываются в модуль."
  default     = {}
}

variable "enable_nat" {
  type        = bool
  description = "Публичный адрес для ВМ."
  default     = true
}
