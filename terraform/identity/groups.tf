# Groups are the source of truth for access.
#
# Nothing downstream grants anything to a person. Mesh access, sudo, device
# assignment and secret access all read group membership, so a change here is
# the only kind of access change there is — which is what makes the access
# matrix generatable and offboarding a single edit. IGN-AC-02.
#
# The rule when adding one: a group needs a name that says who belongs in it
# and a reason that survives being asked. "linux-admins" passes. "team-3"
# does not, and neither does a group created for one system that only ever has
# one member.

locals {
  groups = {
    # Everyone with any access at all. Membership of this is what makes a
    # person resolvable on a host; it grants nothing by itself.
    linux-users = {
      description = "Every person with a login on any Linux host in the estate."
      superuser   = false
    }

    # Administrative privilege, estate-wide. The identity_client role maps this
    # onto sudo. Deliberately one group rather than one per host class: a
    # per-host-class privilege model looks more precise and in practice
    # produces people who are members of all of them.
    linux-admins = {
      description = "Administrative privilege on Linux hosts. Maps to sudo. IGN-AC-06."
      superuser   = false
    }

    # Administers the identity provider itself. Separate from linux-admins
    # because the blast radius is different in kind: this group can grant
    # itself everything else, which is the definition of a different tier.
    identity-admins = {
      description = "Administers the identity provider. Can grant every other access, so membership is the smallest it can be."
      superuser   = true
    }
  }
}

resource "authentik_group" "estate" {
  for_each = local.groups

  name         = each.key
  is_superuser = each.value.superuser

  attributes = jsonencode({
    description = each.value.description
    # Carried into the LDAP view so that a host can tell an estate group from
    # anything else the directory happens to contain.
    managed_by = "terraform/identity"
  })
}
