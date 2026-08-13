# ADR 0003 — `fleetd` as the endpoint agent, not plain osquery

**Status:** accepted
**Date:** 2026-08-12

## Context

The device plane needs to answer "what machines exist and what state are they
in" continuously, and to do it through a channel that did not make the changes
it is reporting on.

osquery answers the question well. It can be pointed at a Fleet server directly,
with a flags file and an enroll secret, and it will report host vitals, software
inventory and policy results. That configuration is appealing: one binary, no
supervisor, nothing that updates itself.

The question is whether reporting is enough.

## Decision

`fleetd` — the Fleet agent bundle, which supervises osquery — is the agent.
Packages are built per organization with `fleetctl package`, and the enroll
secret comes from the secret store rather than a file in the repository.

Four capabilities drove it:

1. **Remote script execution**, which is what makes offboarding actions,
   baseline remediation and incident response possible without physically
   finding a laptop.
2. **Agent auto-update**, so the component that reports on patch currency is not
   itself the stalest thing on the machine.
3. **Software self-service**, which gives users a sanctioned path and therefore
   makes an allowlist enforceable rather than merely declared.
4. **Disk encryption key escrow**, without which `IGN-EP-01` is half a control.

## Alternatives

### Plain osquery against the Fleet API

**Better at:** minimalism, and a genuinely smaller attack surface — an agent
that cannot execute anything cannot be made to execute anything. For a
server-only estate this remains a defensible choice, and this architecture would
not argue hard against it.
**Rejected because:** three of the four capabilities above are not partially
available, they are absent. Escrow in particular cannot be worked around: either
the recovery key reaches a system the organization controls or the encryption
control has a hole in it.

### A commercial endpoint management platform

**Better at:** breadth, support, and Windows and macOS coverage in the same
console.
**Rejected because:** it is outside the premise, and the Linux support in this
category is consistently the weakest part of the product — which is the
condition that created the gap this architecture addresses.

## Consequences

**Easier:** the device plane can act, not only observe. Offboarding can revoke
on the endpoint rather than only in the directory. A failing baseline can be
corrected without a person.

**Harder, and this is the significant one:** the architecture now contains a
write path into every endpoint. That is in tension with the read-only posture
elsewhere, and pretending otherwise would be dishonest. The tension is managed
rather than waved away:

- Scripts are version controlled and applied from a digest-pinned manifest,
  never pasted into a console (`IGN-SC-03`).
- Script execution is enabled per team and **disabled by default**, so
  workstations can be remediable while production servers are not.
- Divergence between what the server holds and the reviewed manifest is a
  finding (`IGN-SC-04`).
- Every run is logged as evidence: who, what, where, when.

**A distinction that must survive into any description of this:** the auditing
tools used to assess an estate hold no write path and never will. Endpoint
script execution is a capability belonging to the organization, in the
organization's own console. Conflating the two would give away a guarantee that
is worth more than the convenience.

## Revisit when

osquery gains escrow and remote execution in a form that does not require a
supervisor, or the estate is servers only — in which case plain osquery is
lighter and the trade reverses.
