# ADR 0004 — Mesh VPN as the network plane, with a documented control-plane choice

**Status:** accepted
**Date:** 2026-08-12

## Context

The network plane has to answer "what can talk to what" for an estate whose
machines are not all in one place: servers in a rack, hypervisors on a
management network, and laptops on whatever network their owner is sitting on
this week.

A perimeter cannot answer that question, because half the estate spends its life
outside the perimeter. What is needed is per-host identity and per-connection
policy, with grants derived from the same groups that drive everything else.

The unavoidable decision inside that is the control plane, and it is the one
place in this architecture where the strongest product is not open source.

## Decision

A WireGuard-based mesh with access control expressed as code, default deny, and
grants derived from identity-provider groups.

**Tailscale is the documented default**, because it is the one most
organizations will actually choose and the one with the least operational
burden. Its control plane is proprietary, and this is stated in the
architecture rather than buried — an estate adopting it should know which part
of its access model depends on a third party.

**Two supported swaps**, both fully open source, both covering the same
interface:

- **Headscale** — a self-hosted control plane speaking the same protocol, with
  the same clients and compatible policy syntax. The smallest change from the
  default and the least rework.
- **NetBird** — fully open source end to end, with native OIDC against the
  identity provider and device posture checks. The strongest fit with the rest
  of this architecture, and the most different from the default.

The mesh is Layer 2 in the dependency ladder, below identity, so that the path
used to reach a broken identity provider does not depend on it.

## Alternatives

### Traditional VPN concentrator

**Better at:** familiarity, and it is what most organizations already have.
**Rejected because:** it produces a perimeter, and a perimeter answers "who is
inside" rather than "what can talk to what." Every host inside it is reachable
by every other, which is the property that turns one compromised laptop into an
estate-wide problem.

### NetBird as the default rather than a swap

**Better at:** consistency with the premise — nothing proprietary anywhere in
the stack, and its posture checks feed the device controls directly.
**Rejected as the default because:** the architecture should document what
organizations will realistically run first, and be honest about the trade rather
than picking the ideologically clean option and being ignored. It is a
first-class supported path, not a footnote.

### No mesh; rely on the identity plane alone

**Better at:** fewer moving parts.
**Rejected because:** identity tells you who someone is, not what their machine
can reach. Without a network plane, every service is exposed to every network
its host is on and the only control is the service's own authentication.

## Consequences

**Easier:** access grants are declarative and reviewable; a laptop's reachable
set is the same whether it is in the office or not; there is no inbound
firewall exception to maintain per service.

**Harder:** group membership has to be reconciled into the mesh's policy.
Depending on the control plane and how the identity provider is registered, this
may not flow automatically and may need reconciliation from the identity
provider's API. This is a known integration cost and is the most likely reason
to move to NetBird earlier than planned.

**Stated openly:** with the default, the availability of the access model
depends on a third-party control plane. Existing sessions survive its outage;
new authentication generally does not. Organizations for whom that is
unacceptable should start on Headscale, and the architecture supports that
without change elsewhere.

## Revisit when

Group synchronization turns out to need enough custom reconciliation that the
native OIDC path is simpler — at which point NetBird becomes the default rather
than a swap.
