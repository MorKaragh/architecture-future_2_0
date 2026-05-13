data "yandex_compute_image" "this" {
  family = var.image_family
}

resource "yandex_compute_disk" "attach" {
  name   = "${var.vm_name}-data"
  zone   = var.zone
  size   = var.attach_disk_size
  type   = var.attach_disk_type
  labels = var.labels
}

resource "yandex_compute_instance" "this" {
  name        = var.vm_name
  platform_id = var.platform_id
  zone        = var.zone
  labels      = var.labels

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.this.id
      size     = var.boot_disk_size
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.attach.id
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = var.enable_nat
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }
}
