# Every value that could tie this lab to one particular estate is a variable.
# Nothing about any specific environment belongs in this directory — the lab
# has to stand up on a hypervisor its author has never seen.

variable "pve_endpoint" {
  description = "Proxmox API endpoint, including scheme and port, e.g. https://hypervisor.example:8006"
  type        = string
}

variable "pve_api_token" {
  description = <<-EOT
    Proxmox API token in `user@realm!tokenid=secret` form.

    The lab creates and destroys virtual machines, so this token needs write
    access — unlike the read-only credentials the architecture uses for
    assessment. Give it a role scoped to the lab's own resource pool rather
    than reusing an administrative token.
  EOT
  type        = string
  sensitive   = true
}

variable "pve_insecure" {
  description = "Skip TLS verification against the Proxmox API. True is common for a lab hypervisor with a self-signed certificate; it is never appropriate anywhere else."
  type        = bool
  default     = false
}

variable "pve_ssh_username" {
  description = "SSH user on the Proxmox node, used only to upload cloud-init snippets. Needs write access to the snippets datastore."
  type        = string
  default     = "root"
}

variable "pve_node" {
  description = "Name of the Proxmox node to build on."
  type        = string
}

variable "pve_datastore" {
  description = "Datastore for virtual machine disks."
  type        = string
  default     = "local-lvm"
}

variable "pve_snippets_datastore" {
  description = "Datastore holding cloud-init snippets. Must have the 'snippets' content type enabled — see lab/README.md."
  type        = string
  default     = "local"
}

variable "pve_uplink_bridge" {
  description = <<-EOT
    Existing bridge the lab gateway uses to reach the internet.

    This is the only point where the lab touches an existing network, and it
    touches it with exactly one interface on one virtual machine. Every other
    machine sits on the isolated bridge below and cannot reach — or be reached
    from — the surrounding network at all.
  EOT
  type        = string
  default     = "vmbr0"
}

variable "lab_bridge" {
  description = "Name of the isolated bridge the lab creates for itself. Must not already exist on the node."
  type        = string
  default     = "vmbr90"
}

variable "lab_network_cidr" {
  description = <<-EOT
    The lab's own network.

    Defaults to a range reserved by RFC 5737 for documentation, which is
    deliberate: it will not collide with any real network, and if one of these
    addresses ever appears somewhere it should not, it is unmistakably from
    the lab.
  EOT
  type        = string
  default     = "192.0.2.0/24"
}

variable "lab_domain" {
  description = "DNS domain served inside the lab. Defaults to a name reserved by RFC 2606 for exactly this purpose."
  type        = string
  default     = "lab.example"
}

variable "vmid_base" {
  description = "Starting VM ID. The lab claims this through vmid_base + 9. Pick a range no existing guest occupies."
  type        = number
  default     = 9200
}

variable "admin_ssh_keys" {
  description = <<-EOT
    Public keys authorized for the bootstrap administrator on every lab machine.

    This account exists to get the lab to the point where the architecture can
    take over. Once the identity plane is running, access arrives by certificate
    and this account becomes the lab's equivalent of a break-glass credential —
    which makes it a useful place to rehearse IGN-AC-07.
  EOT
  type        = list(string)
}

variable "admin_username" {
  description = "Bootstrap administrator account created by cloud-init."
  type        = string
  default     = "labadmin"
}

# Image URLs are variables because they rot. A reference architecture that
# stops standing up when an upstream moves a file has failed at the one thing
# it is for, so these are overridable without editing any Terraform.

variable "debian_image_url" {
  description = "Debian generic cloud image (qcow2)."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "ubuntu_image_url" {
  description = "Ubuntu LTS server cloud image (qcow2)."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "fedora_image_url" {
  description = "Fedora Cloud Base image (qcow2). Pinned to a release rather than 'latest' — Fedora publishes no stable latest symlink."
  type        = string
  default     = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
}
