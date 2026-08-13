# ADR 0002 — SSH access uses short-lived certificates, not authorized-keys files

**Status:** accepted
**Date:** 2026-08-12

## Context

Offboarding is the control organizations claim most confidently and evidence
least well. The usual reason is mechanical: access was granted by appending a
public key to a file on each host, and there is no list of which hosts got it.
Removing that access means finding every `authorized_keys` file that ever
received the key, across machines that may have been built years apart.

Directory integration does not solve this on its own. The account can be
disabled centrally, but a key trusted by `sshd` on a host whose directory client
is degraded, misconfigured, or simply cached may still work.

The requirement is that access ends **by itself**, without anyone remembering
anything, and that the ending is provable.

## Decision

Interactive SSH authenticates with a certificate issued by an internal CA
(`step-ca`) after an OIDC login against the identity provider. Certificates are
valid for one working day. `sshd` trusts the CA through `TrustedUserCAKeys`,
password authentication is off, and `authorized_keys` is not an access path for
human users.

The directory supplies the **identity** — the account, its groups, its sudo
rules. The certificate supplies the **credential**. Those are separate concerns
and separating them is what makes revocation immediate.

## Alternatives

### Long-lived keys distributed by configuration management

**Better at:** simplicity; no CA to run, no new service in the dependency
ladder, and it works when everything else is down.
**Rejected because:** it inverts the revocation problem rather than solving it.
Removal becomes a push that has to reach every host and succeed, and hosts that
were unreachable during the removal keep working keys. The evidence for
offboarding becomes "the playbook reported success," which is a claim about the
tool rather than the estate.

### Keys served from the directory at authentication time

**Better at:** no CA, and revocation is genuinely central — remove the key from
the directory and it stops resolving.
**Rejected because:** it makes every SSH login synchronously dependent on the
directory, which is precisely the dependency the ladder in
[`00-overview.md`](../00-overview.md) exists to bound. When the identity provider
is down, this is the path that stops working, and it is the path you need to fix
it.

### A managed access proxy (Teleport and similar)

**Better at:** session recording, per-session approval, and a genuinely good
audit trail out of the box. If session recording is a requirement, this is the
honest answer.
**Rejected because:** it puts a component in the connection path that has to be
available for access to work, and it is a larger operational commitment than the
rest of this architecture. Revisit if session recording becomes a requirement.

## Consequences

**Easier:** offboarding is a certificate expiry rather than a search. A departed
person's access ends within the certificate lifetime whether or not any cleanup
ran, and the evidence is the CA's issuance log rather than a playbook result.

**Harder:** there is a CA to run, back up, and rotate. Its unavailability stops
new logins — though not existing sessions — so it sits in the same tier as the
identity provider for restore priority.

**Foreclosed:** nothing permanent. Certificate trust is a line in `sshd_config`;
an estate can go back to keys by removing it, which is worth knowing because it
means this is not a one-way door.

**The break-glass interaction is the important one.** Break-glass credentials
(`IGN-AC-07`) are deliberately *not* certificate-based, because the CA is a
Layer 4 service and break-glass has to work at Layer 0. That is not an
inconsistency; it is the ladder doing its job.

## Revisit when

Session recording becomes a requirement, or the certificate lifetime turns out
to be wrong in practice — too short is a support burden, too long weakens
`IGN-AC-03`. One working day is a starting point, not a finding.
