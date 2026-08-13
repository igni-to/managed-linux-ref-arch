# ADR 0005 — OpenBao as the secret store, with a documented commercial swap

**Status:** accepted
**Date:** 2026-08-12

## Context

Secrets in this architecture fall into three groups, and they have genuinely
different requirements:

1. **Break-glass credentials.** Read rarely, by a human, in the worst
   circumstances imaginable. Must be reachable when the identity provider is
   down — Layer 1 in the dependency ladder, below identity.
2. **Automation credentials.** Read constantly, by CI runners and configuration
   management, with no human present and no interactive prompt available.
3. **Application secrets.** Read by services at startup.

The failure mode this plane exists to remove is the file-based credential on an
automation host: a vault password or API token sitting in plaintext at a known
path because the automation is headless and the credential manager is
interactive. It is nearly universal, and it means the automation host holds the
keys to everything the automation can reach.

## Decision

**OpenBao** as the default. AppRole or JWT authentication for automation, so a
runner authenticates as itself and receives a short-lived token rather than
holding a long-lived one. Break-glass credentials in a separate store path with
their own audit device and an alert on read.

**1Password is a documented, supported swap** — service accounts cover the
headless case, and for organizations already using it the operational
familiarity is worth more than the architectural purity of running one more
service. What changes is confined to the secret provider interface.

**The rule that applies to both:** no long-lived secret is written to disk in
plaintext, and no secret is committed. Secrets are injected at run time, into
the process that needs them, with a lifetime.

## Alternatives

### Encrypted secrets in the repository (sops with age, or vault files)

**Better at:** simplicity and availability. There is no service to run, nothing
to be down, and the secrets travel with the code that uses them. For a small
estate this is a reasonable answer and it should not be sneered at.
**Rejected because:** it has no revocation story. Rotating a secret means
rotating it everywhere and hoping every copy is found, and any clone of the
repository from before the rotation still decrypts with the old key. It also
provides no audit record of reads, which `IGN-AC-07` needs for break-glass.

### 1Password as the default rather than the swap

**Better at:** operational maturity, recovery when things go wrong, and the fact
that most organizations already have a password manager and will not want a
second system.
**Rejected as the default because:** the architecture leads with what an
organization can run itself. It is a first-class path, not a compromise — and
for the break-glass case specifically, a well-run commercial password manager
has a genuinely better recovery story than a self-hosted store that might be
down for the same reason everything else is.

### The configuration management tool's own encryption

**Better at:** zero additional components.
**Rejected because:** it addresses only the configuration management use case,
leaves the automation host holding the decryption key, and gives applications
and break-glass nothing.

## Consequences

**Easier:** automation credentials become short-lived and attributable — a
runner's access can be revoked without touching any other consumer, and the
audit device says what read what.

**Harder:** another service in the estate, with its own unsealing, backup and
restore concerns. Unsealing after a restart is the operational detail most
likely to be underestimated.

**The bootstrap problem is real and is not hidden.** Break-glass credentials
live in the secret store; the secret store may need credentials to reach. The
resolution is that break-glass material is *also* held in a form that survives
the estate being entirely unavailable — offline, sealed, and tested during the
quarterly exercise (`IGN-AC-08`). Any design that resolves this circularity only
on paper has not resolved it.

## Revisit when

The estate's automation surface is small enough that a store is more machinery
than it earns, or the organization standardizes on a commercial manager for
other reasons — in which case the swap is the right move rather than a
concession.
