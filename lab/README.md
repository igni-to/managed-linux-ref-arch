# The lab

Five machines on a network of their own, built from nothing by one command and
removed by another.

This is not a demonstration bolted on at the end. **It is how the architecture
is tested.** Every verification step in the repository runs here, including the
ones that require breaking something — taking the identity provider down,
forging a signature, editing a script out from under its manifest. None of that
is safe to do in an estate anybody depends on, which is the argument for
building the lab first.

---

## What gets built

| Machine | Distribution | Purpose | vCPU | RAM | Disk |
|---|---|---|---|---|---|
| `gateway` | Debian | NAT, DNS, the only route in or out | 1 | 1 GB | 8 GB |
| `idp` | Debian | Identity provider | 2 | 4 GB | 20 GB |
| `server-a` | Debian | Directory client, certificate SSH | 1 | 1.5 GB | 12 GB |
| `server-b` | Ubuntu | The same, on a second distribution | 1 | 1.5 GB | 12 GB |
| `desktop` | Fedora | The endpoint half | 2 | 4 GB | 25 GB |

**Total: 7 vCPU, 12 GB RAM, 77 GB disk.** It will run on one modest node.
Memory is the binding constraint; the identity provider and the desktop are
where it goes.

Two distributions from the start is deliberate. "It works on the one we tested"
is how a reference architecture quietly stops being one, and the differences
show up early — in package names, in `sudo` versus `wheel`, in how each image
handles DNS.

## The network

```
        existing network
               │
          [uplink bridge]                       ← the only point of contact
               │
        ┌──────┴──────┐
        │   gateway   │  NAT · DNS · nftables
        └──────┬──────┘
               │
          [lab bridge]                          ← created by Terraform, no ports
               │
   ┌────────┬──┴─────┬──────────┐
  idp    server-a  server-b   desktop
```

The lab bridge has **no physical ports and no uplink**. Nothing on it can reach
or be reached from the surrounding network except through the gateway, which
forwards outbound and drops inbound.

That isolation is not tidiness. This lab runs a directory and a certificate
authority, and either of those loose on a network it does not own is a genuinely
bad day. The one line that would break it is a `ports` attribute on the bridge
resource, and there is a comment there saying so.

Addresses default to `192.0.2.0/24` and the domain to `lab.example` — reserved
by RFC 5737 and RFC 2606 for exactly this. Any lab address appearing somewhere
it should not is therefore unmistakable.

## Prerequisites

**On the hypervisor:**

1. **A datastore with the `snippets` content type enabled.** Cloud-init is
   uploaded as a snippet, and this is the single most common first failure. In
   the Proxmox UI: *Datacenter → Storage → your datastore → Edit → Content →
   add Snippets*.

2. **SSH access to the node for the account in `pve_ssh_username`.** The
   Proxmox API has no endpoint for writing a snippet, so the provider uploads
   over SSH. Your key needs to be in an agent — the provider is configured with
   `ssh { agent = true }`.

3. **An API token that can create and destroy virtual machines.** Scope it to a
   role and pool covering the lab only. Do not reuse an administrative token,
   and do not reuse a read-only assessment token — different jobs, different
   credentials, which is `IGN-AC-02` applied to yourself.

4. **A free VM ID range.** The lab claims `vmid_base` through `vmid_base + 9`.

**Locally:** Terraform 1.9 or newer, and an SSH agent holding the key you list
in `admin_ssh_keys`.

## Running it

```sh
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

make init
make plan      # read this before the first apply
make up
```

`make up` applies, then writes `inventory.ini` and `ssh_config` from live state.
Both are gitignored: they describe a real environment.

```sh
ssh -F ssh_config lab-idp
ansible -i inventory.ini lab -m ping
```

Only the gateway is reachable directly; everything else is proxied through it.
That is the lab demonstrating its own isolation rather than a convenience.

## Tearing it down

```sh
make down
```

Removes the machines and the bridge. Nothing survives, which is the point — if
something in the lab is worth keeping, it belongs in the repository instead.

Rebuilding from nothing is a test in its own right (`docs/00-overview.md`, the
stranger test). A lab that has drifted into being precious has stopped being
able to tell you whether the code still works.

## When it does not work

**`unable to upload file` / snippets errors on first apply.** The snippets
content type is not enabled, or the SSH user cannot write to the datastore. See
prerequisite 1.

**`bridge already exists`.** Something already occupies `lab_bridge`. Pick
another name — it is a variable.

**The gateway address reads `pending`.** The guest agent has not reported yet.
Wait for boot to finish, then `make inventory` again. If it never reports,
`qemu-guest-agent` failed to install, which usually means the machine has no
route out — check the gateway first, because everything else depends on it.

**Machines boot but cannot install packages.** DNS or NAT on the gateway. From
a lab machine, try the gateway address directly: if addresses work and names do
not, it is `dnsmasq`; if neither works, it is `nftables` or forwarding.

**Terraform wants to rebuild everything on every plan.** Usually a changed image
URL — the disk is derived from the downloaded image, so a new upstream file
means new disks. Expected, and a reason the lab is disposable.

## What is deliberately absent

- **No backend configuration.** Lab state describes machines meant to be
  destroyed; it holds nothing anyone needs afterwards. Local state keeps this
  runnable by someone who has not yet stood up a state backend, which matters
  because this is the first thing a newcomer runs. Everything under
  `../terraform/` is different and configures a backend.

- **No configuration beyond bootstrap in cloud-init.** Cloud-init creates an
  administrator, installs the guest agent, and stops. Directory enrollment,
  certificate SSH, the baseline and the agent are applied by Ansible, because
  that is the part being demonstrated. Configuring the estate here would be a
  second, invisible configuration system competing with the one under test.

- **No services on the gateway beyond routing and DNS.** It is not the identity
  provider, not the certificate authority, and not a jump host with tools on it.
  A gateway that accumulates services stops being able to prove the other
  machines work.
