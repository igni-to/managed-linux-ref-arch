# ADR 0001 — Authentik as the identity provider

**Status:** accepted
**Date:** 2026-08-12

## Context

Every other plane derives from identity: mesh grants, sudo rules, device
assignment, secret access. Choosing it badly is expensive to reverse, because
the migration touches everything downstream at once.

The constraints that mattered:

- **Self-hostable, genuinely open source.** An architecture arguing that an
  organization should own its infrastructure cannot put the root of its access
  model on someone else's service.
- **OIDC and SAML and LDAP.** OIDC for modern applications, SAML because some
  business applications still only speak it, and LDAP because Linux host login
  through SSSD needs it.
- **Configurable as code.** Group membership is the source of truth for access
  in this architecture, so it has to be reviewable as a diff.
- **Operable by a small team.** This is for organizations that do not have an
  identity engineer.

## Decision

Authentik, deployed as a container, configured through its Terraform provider.
Users, groups, applications and flows are defined in `terraform/identity/`.

The LDAP outpost provides directory services to Linux hosts via SSSD. OIDC
provides sign-on for applications, the hypervisor UI, and the SSH certificate
authority.

## Alternatives

### Keycloak

**Better at:** maturity, ecosystem, and hiring — it is the identity provider an
experienced engineer is most likely to have already run. Its standards coverage
is the most complete of the three.
**Rejected because:** heavier to operate for the target size, and its
administrative model assumes more identity expertise than the intended operator
has. The realm and client model is powerful and is not self-explanatory, which
matters when the person maintaining it does so occasionally.

### Kanidm

**Better at:** Linux integration, by a wide margin. `kanidm-unixd` is a
purpose-built replacement for the SSSD path rather than an LDAP compatibility
layer, and its security model is the most carefully considered of the three.
**Rejected because:** the application-integration surface is narrower — SAML
support and the breadth of ready-made application integrations are behind
Authentik's, and this architecture has to cover the business applications an
organization already runs, not only its Linux hosts. This is the closest call in
this document, and a Linux-only estate should genuinely consider it.

### A hosted identity provider (Okta, Entra, and similar)

**Better at:** almost everything operationally — availability, conditional
access, and the fact that the failure mode this architecture works hardest to
survive largely disappears when the identity provider is somebody else's problem.
**Rejected because:** it is outside the premise. It is also, honestly, what many
organizations should pick — and if identity is already in Entra or Okta, the
right move is to integrate Linux with it rather than run a second one. The
planes below identity are unchanged in that case; only `terraform/identity/` is
replaced. That path is supported and is not a lesser version of this
architecture.

## Consequences

**Easier:** one deployable covering OIDC, SAML and LDAP; access as a reviewable
diff; no per-seat cost as the estate grows.

**Harder:** the identity provider is now a system to run, back up, restore and
upgrade — and it is inside the estate it governs. Everything in the dependency
ladder, the break-glass controls, and the restore drill exists because of this
decision. That cost is real and is the price of the premise.

**The upgrade path deserves attention.** Authentik moves quickly, and an
identity provider that fails to start after an upgrade takes the estate's access
model with it. Upgrades are staged in the lab, and the restore drill
(`IGN-BR-02`) is the recovery path.

## Revisit when

The organization adopts a hosted identity provider for other reasons — at which
point the correct move is to integrate rather than to run both. Or if Kanidm's
application-integration surface catches up, which would make it the stronger
choice for a Linux-centered estate.
