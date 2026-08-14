# Field notes

Things that were wrong, how they presented, and what the fix was.

This file exists because the expensive part of each entry below was never the
fix — it was the gap between the symptom and the cause. Every one of these was
found by deploying the architecture rather than by reviewing it, which is the
argument for standing the lab up early and the reason each entry records the
*wording* of the failure rather than only its resolution.

Entries are added when something takes more than a few minutes to explain.
A note that only says what to do is half an entry; the half that saves the next
person is what it looked like when it went wrong.

---

## Identity

### An OAuth2 provider with no `grant_types` refuses everything

**Symptom, in three layers, none of which names the field:**

| Where | What it said |
|---|---|
| The application | `login provider denied login request` |
| The application's log | `invalid_request` · "The request is otherwise malformed" |
| The identity provider's log | **`Invalid grant_type for provider`** |

**Cause.** `grant_types` defaults to an empty list, and an empty list permits
nothing. Every authorization request is refused before any credential, group or
claim is evaluated.

**Why it costs time.** Both user-facing messages describe a *user* being denied,
which points at the person, their groups, or their claims — none of which were
ever consulted. Only the third message, one level deeper in the identity
provider's own log, names the actual field.

**Fix.** Set it explicitly on every provider:
`grant_types = ["authorization_code", "refresh_token"]`.

**The general lesson.** When a field is optional, computed, *and* its empty
value is a valid-but-useless configuration, it will eventually be created empty.
Prefer setting such fields explicitly even when a default appears sensible.

### A reverse-proxied application must be told its own public URL

**Symptom.** The authorization request is rejected with a `redirect_uri`
mismatch, and the error surfaces as a problem with the identity provider.

**Cause.** The application builds its redirect URI from whatever hostname it
believes it has. Behind a proxy that is the internal name, not the URL the
browser used, so the URI it sends can never match the one registered.

**Fix.** Set the application's public root URL explicitly — Grafana's
`root_url`, and the equivalent in anything else behind the proxy. Beware
reusing an existing "domain" variable for it: those are often set for display
and predate the estate having a real fully-qualified name.

### Branding assets are not served from where the API implies

**Symptom.** The logo saves without error and the login page shows nothing.

**Cause, in two parts.** The API rejects a leading-slash path outright
(`"Absolute paths are not allowed"`), which pushes you toward a path relative to
the media root — and that saves cleanly and renders nothing, because the version
in use does not serve `/media` at all. `/static/…` answers; `/media/…` returns
404.

**Fix.** Serve the asset from the reverse proxy on the identity provider's own
origin and give the API a full URL, which it accepts.

### A recovery flow has to be built, not enabled

**Symptom.** Minting a recovery link returns `No recovery flow set`, so the only
way to onboard somebody is to hand them a password.

**Cause.** A fresh install ships flows for authentication, invalidation,
authorization and password change — and none with designation `recovery`. The
setting is not unassigned; the object does not exist.

**Fix.** Create the flow and bind the stages the password-change flow already
uses, so a password set through recovery gets the same validation as a password
change. Then attach it to the brand.

---

## Configuration management

### A role that only creates never converges

**Symptom.** An object was created with a bad value. The role is corrected, the
role is re-run, and nothing changes.

**Cause.** Every task guarded on the object being absent. Once it exists, all of
them skip — so the fix reaches new estates and never reaches the one that has
the problem.

**Fix.** Separate *create* from *reconcile*. Create when absent; unconditionally
`PATCH` the fields that matter on every run. A configuration role's job is to
converge, not to seed.

**Worth internalizing:** this failure mode is invisible in review. The role
looks correct, and it is correct — for a system that does not exist yet.

### Ansible's `uri` module does not infer `changed`

**Symptom.** A `POST` that plainly created something reports `ok`. Anything
keyed off `.changed` then takes the wrong branch, and a later task fails on an
empty lookup rather than at the real fault.

**Fix.** Set `changed_when` from the status code, and resolve identifiers from
whether a response body came back rather than from `.changed`.

### Bind mounts do not inherit the image's ownership

**Symptom.** The service answers redirects correctly and then returns 500 when
it renders a page.

**Cause.** Directories created on the host as root, mounted into a container
that runs unprivileged. Named volumes inherit ownership from the image on first
mount; bind mounts show the host's, and the container cannot read them.

**Fix.** Create the directories owned by the container's UID. When a service
answers *some* requests and fails on others, suspect what the failing path
reads.

---

## Networking

### A statically assigned address inside a DHCP pool

**Symptom.** SSH fails with `Permission denied (publickey)` against a host whose
`authorized_keys` is demonstrably correct.

**Cause.** The address was already leased to another device. The new host
answered ARP on its own segment while traffic from elsewhere reached the other
device — so the file being correct and the login failing were both true, of
different machines.

**What identified it.** Two SSH host key fingerprints for one address. That is
the cheap check, and it is decisive:

```sh
ssh-keyscan -t ed25519 <ip> | ssh-keygen -lf -   # what the network answers
# compare against the host's own /etc/ssh/ssh_host_ed25519_key.pub
```

**Fix.** Assign static addresses outside the DHCP range, or reserve them. Verify
an address is free before using it — an ARP check from a host on the same
segment takes seconds and is cheaper than this diagnosis.

### A validation step that cannot see the service's environment

**Symptom.** A configuration file that is valid fails validation, complaining
that a credential is empty.

**Cause.** The credential reaches the running service through a systemd
drop-in. The validation command runs as a separate process that never sees it.

**Fix.** Pass the environment to the validating task explicitly. Note the guard
had been in place for months and had never run against a *changed* file, so it
had never been exercised — a guard that has never failed may never have run.
