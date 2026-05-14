vm_name = "future20-prod"

cores            = 8
memory           = 16
attach_disk_size = 200
attach_disk_type = "network-ssd"
boot_disk_size   = 50

labels = {
  environment = "prod"
  project     = "future20"
}

enable_nat = true
