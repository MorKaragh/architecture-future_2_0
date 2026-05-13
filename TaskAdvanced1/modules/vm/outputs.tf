output "instance_id" {
  description = "Идентификатор ВМ."
  value       = yandex_compute_instance.this.id
}

output "instance_name" {
  description = "Имя ВМ."
  value       = yandex_compute_instance.this.name
}

output "fqdn" {
  description = "FQDN ВМ."
  value       = yandex_compute_instance.this.fqdn
}

output "internal_ip" {
  description = "Внутренний IPv4."
  value       = try(yandex_compute_instance.this.network_interface[0].ip_address, null)
}

output "external_ip" {
  description = "Публичный IPv4 (если включён NAT)."
  value       = try(yandex_compute_instance.this.network_interface[0].nat_ip_address, null)
}

output "attach_disk_id" {
  description = "Идентификатор подключаемого диска."
  value       = yandex_compute_disk.attach.id
}

output "boot_disk_id" {
  description = "Идентификатор загрузочного диска."
  value       = yandex_compute_instance.this.boot_disk[0].disk_id
}
