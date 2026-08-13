terraform {
  required_version = ">= 1.9"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.5"
    }
  }

  # A backend belongs here, unlike in lab/. This state describes who has access
  # to what, so losing it means reconstructing the estate's access model by
  # reading it out of a running system — possible, and not something to do
  # under pressure. Configure it with `terraform init -backend-config=...` so
  # that no specific backend is baked into the repository.
  backend "s3" {}
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
  # Lab deployments present a self-signed certificate. Anywhere else this is a
  # channel carrying an administrative API token, and the answer is a real
  # certificate rather than this flag.
  insecure = var.authentik_insecure
}
