# The OIDC client the SSH certificate authority authenticates people against.
#
# The chain this completes: a person runs `step ssh login`, authenticates here
# with whatever factors the flow requires, and step-ca issues a certificate
# valid for one working day. sshd trusts the CA, so no host holds a per-person
# credential and no authorized_keys file is an access path.
#
# What that buys is IGN-AC-03. Offboarding a person stops their access within
# the certificate lifetime whether or not any cleanup job ran, on every host,
# including the ones that were unreachable at the time. Nothing has to be
# found and removed.

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

resource "authentik_provider_oauth2" "ssh_ca" {
  name      = "ssh-ca"
  client_id = "ssh-ca"

  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id

  # Confidential: step-ca is a server and can hold a secret. The alternative
  # is a public client with PKCE, which exists for software that cannot keep
  # one — and a certificate authority that cannot keep a secret has a larger
  # problem than its OAuth client type.
  client_type = "confidential"

  # Explicit, because the field defaults to an empty list and an empty list
  # permits nothing — every authorization request is then refused before any
  # credential is evaluated. Found the expensive way; see docs/field-notes.md.
  grant_types = ["authorization_code", "refresh_token"]

  # step-ca completes the flow on a loopback listener it opens for the
  # duration of the login. Only loopback is allowed: a redirect URI pointing
  # anywhere else would let an authorization code land somewhere the person
  # running the command does not control.
  allowed_redirect_uris = [
    {
      matching_mode = "regex"
      url           = "^http://127\\.0\\.0\\.1:[0-9]+(/.*)?$"
    }
  ]

  # Tokens here are exchanged immediately for a certificate and never reused,
  # so they are short by design. The certificate's own lifetime is the one
  # that governs access, and it is set on the provisioner in the ssh_ca role.
  access_token_validity = "minutes=5"

  # The subject has to be stable and has to be the username the estate knows,
  # because step-ca turns it into the certificate principal — which is the
  # name sshd matches against. An email or a UUID here produces certificates
  # that authenticate correctly and authorize nobody.
  sub_mode                   = "user_username"
  include_claims_in_id_token = true

  property_mappings = data.authentik_property_mapping_provider_scope.ssh_ca.ids
}

# Group membership has to reach step-ca, because that is what the certificate's
# principals are derived from. Without the groups scope a certificate is issued
# with an identity and no authorization, and every login is refused for reasons
# that look like a host problem.
data "authentik_property_mapping_provider_scope" "ssh_ca" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-email",
  ]
}

resource "authentik_application" "ssh_ca" {
  name              = "SSH certificate authority"
  slug              = "ssh-ca"
  protocol_provider = authentik_provider_oauth2.ssh_ca.id

  meta_description = "Issues short-lived SSH certificates. Managed in terraform/identity."
  meta_hide        = true
}
