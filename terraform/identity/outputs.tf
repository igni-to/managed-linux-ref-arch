# What the rest of the estate needs to know about identity.
#
# These are consumed by the Ansible roles rather than read by a person, which
# is why they are shaped as the values those roles expect rather than as a
# summary. The two search bases in particular have to agree with the
# identity_client role exactly.

output "base_dn" {
  description = "Base DN the directory serves. Must equal idc_base_dn in the identity_client role."
  value       = var.base_dn
}

output "user_search_base" {
  description = "Where hosts look for people."
  value       = "ou=users,${var.base_dn}"
}

output "group_search_base" {
  description = "Where hosts look for groups."
  value       = "ou=groups,${var.base_dn}"
}

output "bind_dn" {
  description = "DN hosts bind as. The password is in the secret store, not here."
  value       = "cn=${authentik_user.ldap_service.username},ou=users,${var.base_dn}"
}

output "groups" {
  description = "Estate groups and their purpose — the access model in one place."
  value = {
    for name, g in local.groups : name => {
      description = g.description
      superuser   = g.superuser
      id          = authentik_group.estate[name].id
    }
  }
}

output "people" {
  description = <<-EOT
    Everyone the directory knows, with membership and whether they are active.

    This is the raw material for the access matrix in the evidence pack, and
    for the offboarding report — an inactive account with the date it became
    inactive is what IGN-AC-03 has to show.
  EOT
  value = {
    for username, p in var.people : username => {
      display_name = p.display_name
      email        = p.email
      groups       = p.groups
      active       = p.active
    }
  }
}

output "posix_ranges" {
  description = "Where directory uids and gids start. Recorded so a host-side collision has something to be checked against."
  value = {
    uid_start = var.uid_start_number
    gid_start = var.gid_start_number
  }
}
