vm_name = "future20-stage"

cores            = 4
memory           = 8
attach_disk_size = 50
attach_disk_type = "network-hdd"
boot_disk_size   = 30

labels = {
  environment = "stage"
  project     = "future20"
}

enable_nat = true
