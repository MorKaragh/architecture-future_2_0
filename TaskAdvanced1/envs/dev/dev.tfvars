vm_name = "future20-dev"

cores            = 2
memory           = 4
attach_disk_size = 20
attach_disk_type = "network-hdd"
boot_disk_size   = 20

labels = {
  environment = "dev"
  project     = "future20"
}

enable_nat = true
