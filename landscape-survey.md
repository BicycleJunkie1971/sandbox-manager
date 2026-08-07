# Landscape Survey

How Sandbox Manager compares to existing VM tools, and which features are
uncommon. This reflects domain knowledge, not an exhaustive live crawl; treat
the "nothing exists" claims as medium confidence and verify before making a
public originality claim.

## Verdict

No existing tool appears to combine all three of these in one lightweight app:

1. A free-space oversubscription verdict from sparse-qcow2 ceiling-vs-allocation
   math.
2. A self-reclaiming ISO library held outside the VM pool.
3. One-click disposable, bare-metal-looking sandboxes with a pay-once guest
   Wi-Fi toggle.

Each ingredient exists somewhere, scattered. The combination appears original.
The oversubscription verdict and the self-reclaiming ISO library are the two
pieces with essentially no close analog among desktop VM tools.

## The neighbors

- virt-manager: canonical GTK/libvirt front end, closest in form. General
  purpose. No oversubscription verdict, no ISO reclaim, no masking default, no
  URL/drag build.
- GNOME Boxes: closest on rootless ease. Downloads and runs distros. No
  oversubscription metering, no ISO reclaim, no masking, no disposable
  workflow.
- Quickemu/Quickgui: closest on one-click acquisition. Raw QEMU, not libvirt.
  Per-VM images, no shared reclaiming library, no oversubscription verdict.
- Cockpit: web UI for libvirt. Shows pool usage, no predictive verdict, no ISO
  reclaim.
- VirtualBox: different stack; guests are easy to detect as virtualized.
- virt-lightning, Vagrant, Multipass: ephemeral or reproducible VM tooling,
  CLI-first. None of the three features.
- Qubes OS: gold standard for disposable VMs, but a whole Xen-based OS, not an
  app on a normal KVM/libvirt desktop.

## Oversubscription verdict

Enterprise stacks solve overcommit warnings, but as pool-fill threshold monitors
for admins, not a per-user ceiling-vs-free verdict: VMware vSphere datastore
alarms, Proxmox with LVM-thin/ZFS, oVirt disk allocation, LVM-thin `dmeventd`.
The building block is standard (`qemu-img info` gives virtual and actual size),
but no known desktop VM GUI renders a plain Safe/Oversubscribed result to one
user.

## Self-reclaiming ISO library

No analog among desktop VM tools. Nearest cousins are container-image garbage
collection (`podman image prune`, Docker dangling-image cleanup) and
package-manager orphan removal, none of them in the VM space.

## Before claiming novelty

Run targeted GitHub/GitLab searches for the two riskiest terms: ceiling-vs-free
oversubscription verdicts, and self-reclaiming ISO libraries. Obscure hobby
projects are the likeliest place a partial match hides.
