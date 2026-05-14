provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

module "vm" {
  source = "../../modules/vm"

  vm_name          = var.vm_name
  zone             = var.zone
  cores            = var.cores
  memory           = var.memory
  subnet_id        = var.subnet_id
  ssh_public_key   = var.ssh_public_key
  attach_disk_size = var.attach_disk_size
  attach_disk_type = var.attach_disk_type
  boot_disk_size   = var.boot_disk_size
  labels           = var.labels
  enable_nat       = var.enable_nat
}
