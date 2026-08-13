# People, and the one service account the directory needs.
#
# Onboarding is adding an entry to var.people and applying. Offboarding is
# setting active = false, which is preferred over deleting: a deleted account
# takes its history with it, and IGN-AC-03 has to be able to show *when* access
# ended. Delete later, deliberately, once nothing needs the record.

resource "authentik_user" "person" {
  for_each = var.people

  username  = each.key
  name      = each.value.display_name
  email     = each.value.email
  is_active = each.value.active

  groups = [
    for g in each.value.groups : authentik_group.estate[g].id
  ]

  # No password attribute. People authenticate through the provider's own
  # flows, with whatever factors those require; a password set here would be
  # one this configuration knows, which is the opposite of the intent.

  lifecycle {
    precondition {
      condition     = alltrue([for g in each.value.groups : contains(keys(local.groups), g)])
      error_message = "Every group in var.people must be defined in groups.tf. A typo here silently grants nothing, which is much harder to notice than an error."
    }
  }
}

# ── the LDAP bind account ───────────────────────────────────────────────────
#
# Hosts bind as this to resolve identities. It is a service account rather than
# a person, and it exists in exactly one place — a shared human account used
# for machine binds is the most common way an estate ends up unable to say who
# did something.
#
# It is a member of nothing. Binding needs to read the directory, not to have
# access to the estate.

resource "authentik_user" "ldap_service" {
  username = "ldap-service"
  name     = "LDAP bind account"
  type     = "service_account"
  password = var.ldap_bind_password
  path     = "service-accounts"

  lifecycle {
    # The password is set once, from the secret store. Rotating it is a
    # deliberate act that has to land on every host at the same time, so it is
    # not something a routine apply should do because a variable moved.
    ignore_changes = [password]
  }
}
