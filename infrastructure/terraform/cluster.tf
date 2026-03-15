terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }

    sops = {
      source = "carlpett/sops"
    }
  }

  backend "s3" {
    bucket = "opentofu"
    endpoints = {
      s3 = "https://s3.biblenas.xyz"
    }
    key = "cluster.tfstate"

    region = "garage"
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
  }
}

data "sops_file" "secrets" {
  source_file = "secrets.enc.yaml"
}

locals {
  master_nodes = {
    kube-master-01 = {
      name = "kube-master-01"
      node_name = "anton"
      vm_id = 100
      ip = "192.168.2.11/24"
      path = "vm-100-disk-1"
    }
    kube-master-02 = {
      name = "kube-master-02"
      node_name = "boris"
      vm_id = 200
      ip = "192.168.2.21/24"
      path = "vm-200-disk-1"
    }
    kube-master-03 = {
      name = "kube-master-03"
      node_name = "costya"
      vm_id = 300
      ip = "192.168.2.31/24"
      path = "vm-300-disk-1"
    }
  }

  worker_nodes = {
    kube-worker-01 = {
      name = "kube-worker-01"
      node_name = "anton"
      vm_id = 101
      ip = "192.168.2.12/24"
      path = "vm-101-disk-1"
    }
    kube-worker-02 = {
      name = "kube-worker-02"
      node_name = "boris"
      vm_id = 201
      ip = "192.168.2.22/24"
      path = "vm-201-disk-1"
    }
    kube-worker-03 = {
      name = "kube-worker-03"
      node_name = "costya"
      vm_id = 301
      ip = "192.168.2.32/24"
      path = "vm-301-disk-1"
    }
  }
}


provider "proxmox" {
  endpoint = "https://anton.biblenas.xyz/"
  api_token =  data.sops_file.secrets.data["proxmox.api_token"]
  insecure = true
}

resource "proxmox_virtual_environment_vm" "kube-masters" {
  for_each = local.master_nodes

  name = each.value.name
  node_name = each.value.node_name
  vm_id = each.value.vm_id

  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = [
      "scsi0",
  ]
  description                          = "Kubernetes master node"
  scsi_hardware                        = "virtio-scsi-pci"
  tablet_device                        = false
  tags                                 = []

  agent {
      enabled = true
      timeout = "15m"
      trim    = false
      type = "virtio"
  }

  cpu {
      cores      = 2
      numa       = false
      type       = "qemu64"
  }

  disk {
      backup            = true
      datastore_id      = "local-zfs"
      discard           = "on"
      interface         = "scsi0"
      path_in_datastore = each.value.path
      replicate         = true
      size              = 33
      ssd               = true
  }

  efi_disk {
      datastore_id      = "local-zfs"
      file_format       = "raw"
      pre_enrolled_keys = false
      type              = "4m"
  }

  initialization {
      datastore_id = "local-zfs"
      interface    = "ide2"

      ip_config {
          ipv4 {
              address = each.value.ip
              gateway = "192.168.2.1"
          }
      }

      user_account {
          keys     = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC31O+05hgYqOnQHfCf7RiuBx5qd7BkuQqvj65hiVOKG+XA0JmgqWFRyKywfqLHXZ7jTahpwq1RbD5r3tB20T01lJGe7XjU01G0RDsqFV9XaYC8pCPh/eXa3RPAFhngZyRn+4cAUlZQasH7onXfXDyDbahnXW9bbss4m6EBadWmQ+/bfhg84YgTszZakP3yvBQO3LSMRvqjppT5Nz8v/6CXGmH/prjnE7n6nAgsDTbLdlSMS8d79y6M6opCR6l8Bv7qX5e6wHNA5+8T/7NtFJzj4xsGXmakCySJMLHaqZKCBE8ODV74F/KAzQqfSLBpa6gUbIvkdThnqcqZwTgNFHlB07s0Ojll8PAyErtbdotyqYGDT4nH/PhOKIfGte8OXnjr3XpMKmo91KcLbW8wqr+lAeuNKhHBYisYP+g8HTp8OdFZwwl6PZ6uwh3e/s1kzFQhDdzvNwpB+J1+pmuCFro9ko7VaWeuDowdFajD7DYuUcLHwS6uQYiwZiTEDrRc4D8= bibletoon@Bibletoon",
          ]
          password = data.sops_file.secrets.data["proxmox.user.password"]
          username = data.sops_file.secrets.data["proxmox.user.username"]
      }
  }

  memory {
      dedicated      = 4096
  }

  network_device {
      bridge       = "vmbr0"
      model        = "virtio"
  }

  operating_system {
      type = "l26"
  }

  serial_device {
      device = "socket"
  }
}

resource "proxmox_virtual_environment_vm" "kube-workers" {
  for_each = local.worker_nodes

  name = each.value.name
  node_name = each.value.node_name
  vm_id = each.value.vm_id

  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = [
      "scsi0",
  ]
  description                          = "Kubernetes worker node"
  scsi_hardware                        = "virtio-scsi-pci"
  tablet_device                        = false
  tags                                 = []

  agent {
      enabled = true
      timeout = "15m"
      trim    = false
      type = "virtio"
  }

  cpu {
      cores      = 4
      numa       = false
      type       = "x86-64-v3"
  }

  disk {
      backup            = true
      datastore_id      = "local-zfs"
      discard           = "on"
      interface         = "scsi0"
      path_in_datastore = each.value.path
      replicate         = true
      size              = 306
      ssd               = true
  }

  efi_disk {
      datastore_id      = "local-zfs"
      file_format       = "raw"
      pre_enrolled_keys = false
      type              = "4m"
  }

  initialization {
      datastore_id = "local-zfs"
      interface    = "ide2"

      ip_config {
          ipv4 {
              address = each.value.ip
              gateway = "192.168.2.1"
          }
      }

      user_account {
          keys     = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC31O+05hgYqOnQHfCf7RiuBx5qd7BkuQqvj65hiVOKG+XA0JmgqWFRyKywfqLHXZ7jTahpwq1RbD5r3tB20T01lJGe7XjU01G0RDsqFV9XaYC8pCPh/eXa3RPAFhngZyRn+4cAUlZQasH7onXfXDyDbahnXW9bbss4m6EBadWmQ+/bfhg84YgTszZakP3yvBQO3LSMRvqjppT5Nz8v/6CXGmH/prjnE7n6nAgsDTbLdlSMS8d79y6M6opCR6l8Bv7qX5e6wHNA5+8T/7NtFJzj4xsGXmakCySJMLHaqZKCBE8ODV74F/KAzQqfSLBpa6gUbIvkdThnqcqZwTgNFHlB07s0Ojll8PAyErtbdotyqYGDT4nH/PhOKIfGte8OXnjr3XpMKmo91KcLbW8wqr+lAeuNKhHBYisYP+g8HTp8OdFZwwl6PZ6uwh3e/s1kzFQhDdzvNwpB+J1+pmuCFro9ko7VaWeuDowdFajD7DYuUcLHwS6uQYiwZiTEDrRc4D8= bibletoon@Bibletoon",
          ]
          password = data.sops_file.secrets.data["proxmox.user.password"]
          username = data.sops_file.secrets.data["proxmox.user.username"]
      }
  }

  memory {
      dedicated      = 16384
  }

  network_device {
      bridge       = "vmbr0"
      model        = "virtio"
  }

  operating_system {
      type = "l26"
  }

  serial_device {
      device = "socket"
  }
}
