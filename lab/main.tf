# The lab estate: five machines on a network of their own.
#
# Shape and why:
#
#   gateway   The only machine touching the surrounding network. Two interfaces:
#             one on the existing uplink bridge, one on the lab's isolated
#             bridge. It does NAT and DNS so the other four can install
#             packages without being reachable from anywhere.
#
#   idp       The identity provider. Sized larger than the rest because it is
#             the one service here that genuinely wants memory.
#
#   server-a  Debian. Directory client, certificate-based SSH, the ordinary
#   server-b  Ubuntu. Two distributions from the start, because "it works on
#             the one we tested" is how a reference architecture stops being one.
#
#   desktop   Fedora. The endpoint half — disk encryption, screen lock, the
#             verified pull loop.
#
# The isolation is the important part. This lab runs a directory, and a
# directory that leaks onto a network it does not own is a genuinely bad day.
# Only the gateway can see beyond the lab bridge.

locals {
  # Addresses derived from the network variable, so changing the CIDR moves
  # everything coherently and no address is written down twice.
  gateway_ip = cidrhost(var.lab_network_cidr, 1)
  netmask    = split("/", var.lab_network_cidr)[1]

  machines = {
    gateway = {
      vmid_offset = 0
      role        = "gateway"
      ip          = cidrhost(var.lab_network_cidr, 1)
      cores       = 1
      memory      = 1024
      disk_gb     = 8
      image       = proxmox_download_file.debian.id
      uplink      = true
    }
    idp = {
      vmid_offset = 1
      role        = "idp"
      ip          = cidrhost(var.lab_network_cidr, 10)
      cores       = 2
      memory      = 4096
      disk_gb     = 20
      image       = proxmox_download_file.debian.id
      uplink      = false
    }
    server-a = {
      vmid_offset = 2
      role        = "server"
      ip          = cidrhost(var.lab_network_cidr, 20)
      cores       = 1
      memory      = 1536
      disk_gb     = 12
      image       = proxmox_download_file.debian.id
      uplink      = false
    }
    server-b = {
      vmid_offset = 3
      role        = "server"
      ip          = cidrhost(var.lab_network_cidr, 21)
      cores       = 1
      memory      = 1536
      disk_gb     = 12
      image       = proxmox_download_file.ubuntu.id
      uplink      = false
    }
    desktop = {
      vmid_offset = 4
      role        = "desktop"
      ip          = cidrhost(var.lab_network_cidr, 30)
      cores       = 2
      memory      = 4096
      disk_gb     = 25
      image       = proxmox_download_file.fedora.id
      uplink      = false
    }
  }
}

# ── the lab's own bridge ────────────────────────────────────────────────────
#
# No ports and no uplink: nothing on this bridge reaches the surrounding
# network except through the gateway virtual machine. Creating it here rather
# than by hand means `terraform destroy` takes it away again.

resource "proxmox_network_linux_bridge" "lab" {
  node_name = var.pve_node
  name      = var.lab_bridge
  comment   = "Managed Linux reference architecture lab — isolated, no uplink"

  # Deliberately no `ports`. A bridge with a physical port is not isolated,
  # and adding one here is the change that would quietly put a directory on
  # somebody's office network.
}

# ── cloud images ────────────────────────────────────────────────────────────

resource "proxmox_download_file" "debian" {
  content_type = "iso"
  datastore_id = var.pve_snippets_datastore
  node_name    = var.pve_node
  url          = var.debian_image_url
  # Proxmox expects a disk image to look like one. The upstream files are
  # .qcow2, which it will not accept under this content type.
  file_name = "lab-debian-cloud.img"
  overwrite = false
}

resource "proxmox_download_file" "ubuntu" {
  content_type = "iso"
  datastore_id = var.pve_snippets_datastore
  node_name    = var.pve_node
  url          = var.ubuntu_image_url
  file_name    = "lab-ubuntu-cloud.img"
  overwrite    = false
}

resource "proxmox_download_file" "fedora" {
  content_type = "iso"
  datastore_id = var.pve_snippets_datastore
  node_name    = var.pve_node
  url          = var.fedora_image_url
  file_name    = "lab-fedora-cloud.img"
  overwrite    = false
}

# ── cloud-init ──────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.machines

  content_type = "snippets"
  datastore_id = var.pve_snippets_datastore
  node_name    = var.pve_node

  source_raw {
    file_name = "lab-${each.key}-user-data.yaml"
    data = each.value.role == "gateway" ? templatefile("${path.module}/cloud-init/gateway.yaml.tftpl", {
      hostname       = each.key
      domain         = var.lab_domain
      admin_username = var.admin_username
      admin_ssh_keys = var.admin_ssh_keys
      lab_cidr       = var.lab_network_cidr
      gateway_ip     = local.gateway_ip
      netmask        = local.netmask
      machines       = local.machines
      }) : templatefile("${path.module}/cloud-init/common.yaml.tftpl", {
      hostname       = each.key
      domain         = var.lab_domain
      admin_username = var.admin_username
      admin_ssh_keys = var.admin_ssh_keys
      role           = each.value.role
    })
  }
}

# ── the machines ────────────────────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "lab" {
  for_each = local.machines

  name        = "lab-${each.key}"
  description = "Managed Linux reference architecture lab — ${each.value.role}. Disposable; rebuilt by terraform apply."
  tags        = ["lab", "reference-architecture", each.value.role]
  node_name   = var.pve_node
  vm_id       = var.vmid_base + each.value.vmid_offset

  # The agent reports the addresses back, which is what lets the generated
  # inventory be real rather than a restatement of what was requested.
  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    # Not "host": a lab that only boots on the processor it was built on is a
    # lab that cannot be handed to anybody.
    type = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.pve_datastore
    file_id      = each.value.image
    interface    = "virtio0"
    size         = each.value.disk_gb
    discard      = "on"
    ssd          = true
  }

  # The uplink interface comes first on the gateway so that it becomes the
  # default route, which is the whole reason that machine exists.
  dynamic "network_device" {
    for_each = each.value.uplink ? [1] : []
    content {
      bridge = var.pve_uplink_bridge
    }
  }

  network_device {
    bridge = proxmox_network_linux_bridge.lab.name
  }

  initialization {
    datastore_id = var.pve_datastore

    # Gateway: DHCP on the uplink, static inside the lab.
    dynamic "ip_config" {
      for_each = each.value.uplink ? [1] : []
      content {
        ipv4 {
          address = "dhcp"
        }
      }
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${local.netmask}"
        # The gateway is its own router, so it has no gateway on this side.
        gateway = each.value.uplink ? null : local.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }

  operating_system {
    type = "l26"
  }

  # Everything else needs the gateway for DNS and package installation, so
  # bring it up first rather than letting four machines race a missing route.
  depends_on = [proxmox_network_linux_bridge.lab]

  lifecycle {
    ignore_changes = [
      # Regenerated on every plan otherwise, which makes every plan look like
      # it wants to rebuild the estate.
      initialization[0].user_account,
    ]
  }
}
