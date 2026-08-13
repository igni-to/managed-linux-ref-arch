# 06 — Provenance

Where executing code comes from, and how a host knows before it runs it.

---

## The rule

> **Nothing executes on a host unless its source is version controlled,
> reviewed, signed, and verified against a pinned allowed-signers list at the
> point of execution.**

Four clauses, each removing a distinct failure:

| Clause | Removes |
|---|---|
| Version controlled | Code with no history and no author |
| Reviewed | Code one person could put everywhere alone |
| Signed | Code altered between review and execution |
| Verified **at the point of execution** | Code that was verified somewhere other than where it ran |

The last clause is the one that gets dropped, because verification usually
happens in CI and that feels sufficient. It is not: CI verifies what was
proposed, and the host executes what it fetched. Anything that can change
between those two moments — a compromised mirror, a rewritten branch, a
misconfigured remote — is invisible unless the host checks for itself.

## Four paths

Code reaches a host four ways. Securing one well while leaving the others open
is worse than doing nothing, because it creates the impression that the question
was considered.

![Four execution paths — remote scripts, the endpoint pull loop, packages and images, and the enrollment bootstrap — each passing through their own verification gate before anything executes on the host. The pull loop's gate has a second outcome: on a verification failure it exits without running rather than falling back to the last good revision.](img/provenance.svg)

### 1 · Remotely executed scripts

The most obvious path, and the best behaved once it is set up.

Scripts live in `scripts/`, reviewed under `CODEOWNERS`, and are applied to the
device platform by Terraform from a manifest of content digests. Nothing is
pasted into a console.

A periodic job compares what the platform holds against the manifest. A
mismatch means someone used the console or the API directly, and it is reported
as a finding rather than a warning — see `IGN-SC-04`. This is the check that
catches a real person under time pressure, which is the realistic threat here,
not an attacker.

### 2 · The endpoint configuration loop

**The dangerous one, because it looks safe.**

`ansible-pull` clones a repository and executes what it finds, on a timer, as
root. It performs **no signature verification by default**. An endpoint pull
loop configured the obvious way is a remote code execution path with a systemd
timer attached, and it will run whatever the remote served.

The unit therefore verifies before it runs:

```
fetch → git verify-commit against .allowed_signers → run, or exit non-zero
```

**It fails closed.** On a verification failure the run stops and reports. It
does not fall back to the previously fetched revision, because an endpoint
quietly re-running last week's configuration looks healthy while being
unmanaged — the worst of both states. See `IGN-SC-02`.

### 3 · Packages and images

The highest-volume execution path in any estate, and the least examined.

Repositories are configured with pinned signing keys and signature checking
enabled, and signature checking is never disabled — not temporarily, not for one
package. A repository added without a pinned key trusts whatever the mirror
serves, which is a trust decision made by omission. See `IGN-SC-05`.

### 4 · The enrollment bootstrap

The genuine chicken-and-egg: the first script runs before the machine trusts
anything, so there is nothing yet to verify against.

This cannot be solved, only bounded:

- Fetched over TLS, and pinned by a digest published in this repository, so the
  operator can compare before running.
- Its **only** job is to install the trust roots — the allowed-signers file, the
  CA certificates, the repository keys — and hand off. Everything else happens
  after verification is possible.
- Short enough that a cautious operator can read the whole thing first. If it
  grows past that, it has taken on work that belongs after the handoff.

## Signing mechanics

Git commit signing with SSH keys:

```
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true
git config gpg.ssh.allowedSignersFile .allowed_signers
```

SSH rather than GPG because the keys already exist, the agents already exist,
and the operational burden of GPG key management is the reason signing gets
abandoned. The goal is signing that survives contact with a normal week.

`.allowed_signers` is committed, so adding a signer is a reviewable diff rather
than a change someone makes on their own machine. Removing a key does not
invalidate history signed with it — it stops that key signing anything new,
which is the property offboarding needs.

Registering the key with the Git host matters: a key registered only for
authentication signs fine and verifies nowhere.

## This repository follows its own rule

`IGN-SC-01` is the only control currently marked `implemented`, and it is
implemented here — signed history, `CODEOWNERS` on the execution paths, and CI
that rejects unverified commits.

That ordering is deliberate. A repository that documents provenance while
accepting unsigned commits is arguing against itself, and the objection would be
correct. It also means the repository's own history is the first evidence
artifact the architecture produces.

## Where this does not reach

Stated plainly, because a control's boundary is part of the control:

- **Signing proves who, not what.** A signed commit from a compromised developer
  machine verifies perfectly. Review is what addresses that, which is why both
  clauses exist and why `CODEOWNERS` covers the execution paths specifically.
- **Upstream package contents are not verified by this**, only their origin. A
  signed package from a compromised upstream is a signed compromised package.
  Bounding that is a supply-chain problem larger than this architecture.
- **The bootstrap remains trust-on-first-use.** Bounded, not eliminated.
