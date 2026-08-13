terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.98"
    }
  }

  # No backend block on purpose.
  #
  # The lab is disposable by design: its state describes machines that are
  # meant to be destroyed and recreated, and it holds no record anybody needs
  # after `terraform destroy`. Local state keeps the lab runnable by someone
  # who has not yet stood up a state backend, which matters because this is
  # the first thing a newcomer runs.
  #
  # Everything under ../terraform/ is different — that state describes an
  # estate people depend on, and configures a backend accordingly.
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = var.pve_insecure

  # Uploading cloud-init snippets goes over SSH rather than the API: the
  # Proxmox API has no endpoint for writing to a snippets datastore. This is a
  # provider requirement rather than a choice, and it is the single most common
  # reason a first `apply` fails — see lab/README.md.
  ssh {
    agent    = true
    username = var.pve_ssh_username
  }
}
