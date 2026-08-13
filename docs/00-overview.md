# 00 — Overview

The estate model, what depends on what, and the four rules that fall out of it.

---

## The seven planes

An estate is easier to reason about as layers of control than as a list of
machines. Each plane answers one question, and each depends only on the planes
below it.

| Plane | The question it answers | Default |
|---|---|---|
| **1 · Identity** | Who exists, and what are they a member of? | Authentik |
| **2 · Access** | What can they reach, and for how long? | SSSD, SSH certificates from step-ca, group-derived sudo |
| **3 · Network** | What can talk to what? | Mesh VPN, default deny, grants from identity groups |
| **4 · Device** | What machines exist, and what state are they in? | Fleet with `fleetd` |
| **5 · Configuration** | How does a machine get into that state? | Ansible push for servers, verified pull for endpoints |
| **6 · Secrets** | Where do credentials live, and who can read them? | OpenBao |
| **7 · Evidence** | How would you prove any of the above? | Control catalog and the generated pack |

Every default has a documented alternative in [`adr/`](adr/), including what you
give up by switching. Nothing in the architecture depends on a specific vendor
at any layer; the interfaces are the layer boundaries, not the products.

---

## The dependency ladder

**The identity provider is a server inside the estate it governs.** That single
fact causes the failure mode that this architecture is arranged to survive:

> The identity provider is down. Logging into the hypervisor requires the
> identity provider. Starting the identity provider requires logging into the
> hypervisor.

Most reference architectures draw identity at the bottom of the diagram, which
is where the circularity hides. Drawing it truthfully means declaring, for each
layer, what it is allowed to depend on:

![The dependency ladder: six layers with every dependency arrow pointing downward, a break-glass path running from an operator at a console straight to Layer 0, and a crossed-out upward edge marked "never federated".](img/dependency-ladder.svg)

| Layer | What it is | Depends on |
|---|---|---|
| 0 | Physical and hypervisor console, break-glass credentials | nothing |
| 1 | Secret store | nothing at authentication time |
| 2 | Network — the mesh | 0 |
| 3 | Identity — the identity provider | 0, 2 |
| 4 | Access — SSH certificates, sudo, service sign-on | 3 |
| 5 | Device, configuration, evidence | 3, 4 |

**Nothing may depend on a layer above it.** That is the whole rule, and the four
consequences below are what it means in practice.

### Rule 1 — Layer 0 never authenticates against Layer 3

The hypervisor keeps a local administrative realm permanently. It also gets
single sign-on, because day-to-day administration should go through the
identity provider like everything else. But the local realm is never disabled,
and it is never federated.

The temptation to "finish the job" by turning it off is exactly the change that
makes the estate unrecoverable, and it always looks like an improvement in the
pull request.

### Rule 2 — Break-glass is an exercised procedure, not a rumor

One sealed credential per host class. In the secret store, not in a drawer and
not in someone's head. Three properties make it a control rather than a back
door:

- **Its use raises an alert**, within minutes, to a human.
- **It is exercised quarterly**, and the exercise produces a dated record.
- **The exercise includes checking that the alert fired.** An alert nobody has
  seen work is a configuration, not a control.

See [`IGN-AC-07`](../controls/access-control.yaml) and `IGN-AC-08`.

### Rule 3 — The credential cache is load-bearing, so it gets tested

When hosts authenticate against a directory, the directory becomes a
dependency of logging in. Credential caching is what keeps that survivable, and
it is invariably configured once and never verified.

So it is configured explicitly — caching on, with a stated expiration — and
there is a test that takes the identity provider down and proves a cached login
still works. An untested cache is not a control; it is an assumption with a
config file.

### Rule 4 — The identity provider is the most restore-critical system

While it is down, the normal path to every other system is down with it. It
gets its own restore drill rather than a line in a general backup job, and the
drill ends with someone logging into the restored copy — because a restore that
completes and cannot authenticate has not been tested, only performed.

See [`IGN-BR-02`](../controls/backup-restore.yaml).

---

## Two loops, deliberately separate

Configuration is **enforced** by one system and **verified** by another.

![Git feeds an Ansible push for servers and a verified pull loop for endpoints, both writing to hosts. Separately the Fleet agent reads state from those same hosts into the evidence pack, catching a change made by hand as drift.](img/enforce-verify.svg)

The separation is the point. A configuration tool reporting that it applied a
change is reporting on its own behavior, not on the machine's state — it will
report success on a host where the change was reverted an hour later. Evidence
comes from the system that had no hand in making the change.

This also gives drift a definition: the enforcing system says what should be
true, the verifying system says what is, and the gap between them is a number
someone can be accountable for.

---

## Provenance: one rule for four paths

Code reaches a host four ways, and securing one of them well is worse than
useless, because it suggests the others were considered.

> **Nothing executes on a host unless its source is version controlled,
> reviewed, signed, and verified against a pinned allowed-signers list at the
> point of execution.**

The four paths and how each satisfies it are in
[`06-provenance.md`](06-provenance.md). The one worth naming here is the
endpoint pull loop, because it is the one that looks safe: `ansible-pull` clones
a repository and executes it, with no signature verification by default. Left
alone, it is a remote code execution path with a systemd timer attached.

---

## What "done" means for an engagement

Handover is a deliverable with a definition, not a sentiment:

- **Runbooks** written for the person doing it at 2am, not the person who built
  it.
- **Everything in version control**, in the organization's own repository,
  using tools they can hire for.
- **No component that only one person understands** in the delivery path.
- **A named owner** who has performed each procedure once, with someone
  watching — not seen it demonstrated.

If the architecture works, the organization needs outside help less each
quarter. That is the intended outcome.
