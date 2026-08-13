# The LDAP interface hosts authenticate against.
#
# Three pieces: a provider that defines what LDAP looks like, an application
# that governs who is allowed to use it, and an attachment binding the provider
# to an outpost that actually serves it.
#
# The third is the one that catches people out. A provider with no outpost is
# configured, valid, and answers nothing — hosts get connection refused on 636
# and the identity provider's own interface shows no error at all.

data "authentik_flow" "authentication" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_ldap" "estate" {
  name    = "estate-ldap"
  base_dn = var.base_dn

  bind_flow   = data.authentik_flow.authentication.id
  unbind_flow = data.authentik_flow.invalidation.id

  # Bind against the directory's own records rather than delegating to an
  # upstream source. "cached" would be faster and would mean a password change
  # takes effect on a schedule instead of immediately, which is the wrong trade
  # for the credential that gates every host.
  bind_mode   = "direct"
  search_mode = "direct"

  # POSIX identity ranges. These are what make a directory account into a
  # usable Unix account, and the defaults start well clear of the ranges
  # distributions use for local accounts — see variables.tf.
  uid_start_number = var.uid_start_number
  gid_start_number = var.gid_start_number

  # Whether a host can present a second factor during an LDAP bind. Off: SSSD
  # has nowhere to prompt for one during `getent`, and turning it on produces
  # authentication that works interactively and fails for every service.
  mfa_support = false
}

# Access to the LDAP interface is governed like any other application, which
# means "which hosts may use the directory" is answerable from the same place
# as every other access question rather than from a config file somewhere.
resource "authentik_application" "ldap" {
  name              = "Estate LDAP"
  slug              = "estate-ldap"
  protocol_provider = authentik_provider_ldap.estate.id

  meta_description = "The directory interface Linux hosts bind to. Managed in terraform/identity."
  # Nothing for a person to click. Showing it on the user portal invites
  # somebody to try, and there is nothing there for them.
  meta_hide = true
}

# ── serving it ──────────────────────────────────────────────────────────────
#
# The embedded outpost — the one that ships with the identity provider and runs
# inside the same process. Looked up rather than created, because it already
# exists and Terraform creating a second one named the same way would fail.
#
# Using the embedded outpost is a deliberate trade, made in the deployment role
# and repeated here because this is where its consequence lives: LDAP is served
# by the same process as the web interface, so they fail together. The
# alternative — a separate outpost container — needs a token that only exists
# after this configuration has run, which makes the deployment two-phase with a
# manual handoff in the middle.
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

resource "authentik_outpost_provider_attachment" "ldap" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_ldap.estate.id
}
