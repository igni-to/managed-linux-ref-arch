variable "authentik_url" {
  description = "Base URL of the identity provider, e.g. https://idp.example"
  type        = string
}

variable "authentik_token" {
  description = <<-EOT
    API token.

    On a first run this is the bootstrap token the deployment role set from the
    secret store, which is what allows this configuration to apply with nobody
    opening the web interface. Replace it with a token belonging to a named
    automation account once the estate is running — the bootstrap token belongs
    to the built-in administrator, and IGN-AC-01 has an opinion about that.
  EOT
  type        = string
  sensitive   = true
}

variable "authentik_insecure" {
  description = "Skip TLS verification. Reasonable against a lab with a self-signed certificate, and nowhere else."
  type        = bool
  default     = false
}

variable "base_dn" {
  description = <<-EOT
    LDAP base DN the provider serves.

    Must match idc_base_dn in the identity_client Ansible role. When they
    disagree, hosts join without error and then report that every user does not
    exist, which is a long way from the actual cause.
  EOT
  type        = string
  default     = "DC=lab,DC=example"
}

variable "ldap_bind_password" {
  description = "Password for the LDAP service account that hosts bind as. From the secret store; never committed."
  type        = string
  sensitive   = true
}

variable "uid_start_number" {
  description = <<-EOT
    First uid the directory hands out.

    Deliberately high, to stay clear of local accounts. Distributions allocate
    system accounts below 1000 and local users from 1000 up; a directory that
    overlaps that range produces two accounts with one uid, which presents as
    files owned by the wrong person and is thoroughly confusing to diagnose.
  EOT
  type        = number
  default     = 20000
}

variable "gid_start_number" {
  description = "First gid the directory hands out. Same reasoning as uid_start_number."
  type        = number
  default     = 20000
}

variable "people" {
  description = <<-EOT
    The people in the estate, and what they are a member of.

    This is the source of truth for access. Adding someone here and applying is
    the whole of onboarding; removing them is the whole of offboarding, and
    every downstream grant follows from group membership rather than from
    anything anyone does per system. IGN-AC-01 and IGN-AC-02.
  EOT
  type = map(object({
    display_name = string
    email        = string
    groups       = list(string)
    active       = optional(bool, true)
  }))
  default = {}
}
