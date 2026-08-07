# Sandbox Manager: Documentation

Version history, setup, and architecture, inception through v1.6.

A GTK control panel for disposable KVM/libvirt Linux VMs. Built on Debian
(ThinkPad X240, dual-core i5, 8 GB RAM, LUKS full-disk encryption over LVM).
Python 3, GTK 3.

## What it does

Build a VM from an ISO or URL, run it in a window, delete it when done. Guest
disks sit on the LUKS volume, so they are encrypted at rest. Installer images
clean up after themselves. A running VM can be handed a physical USB Wi-Fi
adapter.

Design rules that held across all versions:

1. No sudo in normal use. Privileged work goes through libvirt; the user is in
   the `libvirt` group and the daemon does the writes.
2. Guest disks live on the LUKS pool, so they inherit host encryption at rest.
3. Guests use `host-passthrough` CPU and hidden hypervisor flags so software
   inside does not trivially detect a VM. Defeats casual checks, not timing
   analysis.
4. Every privileged action is echoed to a visible log with the command and
   libvirt's output.

## Host setup (pre-1.0)

The stack has to exist before the app. `setup.sh` automates this. Manual steps
and the problems hit during bring-up:

- Confirmed VT-x, RAM, and disk.
- Installed KVM, QEMU, libvirt, virtinst, virt-manager. `libvirt-daemon-system`
  needs `iptables` or `firewalld`; locally pinned newer `libxtables12` and
  `libnftables1` blocked it. Fixed by downgrading those to the Debian versions
  in one `apt install --allow-downgrades` transaction.
- Added the user to `libvirt` and `kvm`, enabled `libvirtd`. Requires re-login.
- URI mismatch: pool and network were defined under `qemu:///session` while the
  VMs needed `qemu:///system`. Fixed by exporting
  `LIBVIRT_DEFAULT_URI=qemu:///system`, later baked into the app.
- Permission wall: the QEMU process runs as `libvirt-qemu` (uid 64055) and
  cannot traverse a mode-700 home directory. Pool moved to
  `/var/lib/libvirt/images`. Drives the ISO-library design in v1.1.
- `default` NAT network was inactive; defined, started, autostarted.
- Local osinfo DB did not know newer Debian IDs. Standard flag became
  `--osinfo detect=on,require=off`.
- First VM: Debian 13.6 XFCE, `host-passthrough`. Proved the chain, motivated a
  purpose-built panel instead of the heavy libvirt toolchain.

## Version history

### v1.0
First GTK app. Live space dashboard (free space, provisioned ceilings, actual
allocation, Safe/Oversubscribed verdict, 4-second refresh). Sandbox list with
Launch and Delete. Add from ISO URL with optional SHA256, RAM and disk
spinners, threaded download and build via `virt-install`. Rootless.
Fixed: `vol-info --bytes` returns `<n> bytes`; parser crashed on `int()`. Take
the numeric token only.

### v1.1
ISO field accepts a URL or a local path, plus a Browse button. Installer images
moved to `/srv/isos`, outside the pool, on a world-traversable path the QEMU
user can read. Ends the v1.0 behavior of copying every ISO into the pool
(double storage). Pool now holds only VM disks.
Setup: `sudo mkdir -p /srv/isos; sudo chown $USER:$USER /srv/isos; chmod 755 /srv/isos`.

### v1.2
Drag-and-drop an ISO onto the field.

### v1.3
Status label replaced with a scrollable, selectable, copyable log. Local ISOs
are relocated into the library on build, so building from a file anywhere avoids
the read-permission wall. Moves, does not copy.

### v1.4
Relocation hardening. libvirt's security driver chowns a disk/CDROM to
`libvirt-qemu` on VM start and may not hand it back if the VM dies. A later
`chmod` then returns EPERM. Fix: `chmod` is best-effort; a file the user cannot
chmod is used as-is since it stays readable. Also skip re-moving a file already
in the library.

### v1.5
Deleting a sandbox reclaims its ISO if no other VM references it. Works even on
libvirt-owned files because the user owns the library directory (unlink needs
directory write, not file ownership). Added a "Purge unused ISOs" button.
Validated by building Kali with an undersized disk and filling it during
install: the guest failed cleanly, the app kept metering, and delete reclaimed
disk and ISO.

### v1.6
USB Wi-Fi passthrough for the Atheros AR9271 (`0cf3:9271`).

- Per-sandbox Attach Wi-Fi / Detach Wi-Fi button.
- Matched by `vendor:product`, so a replug that renumbers the device does not
  break the match.
- One VM at a time; attaching detaches from the current holder first.
- Live state per row; button disabled with a reason when it cannot act.
- Attach and detach echo the command and libvirt output to the log.

Mechanism: a `managed='yes'` USB hostdev, keyed to `WIFI_USBID`, attached
`--live` only (never written to persistent config). Presence is checked each
refresh from `lsusb`; per-VM ownership from the domain's live XML.

Field problems:

- `error -110` (descriptor read failures) came from a degraded physical USB
  port, not the passthrough. The host threw the same `-110` before a clean
  reseat. Fix is physical: reseat, or reboot the host to reset a latched
  controller. After reseat the firmware loaded (`htc_9271-1.4.0.fw`, 51008
  bytes) and the adapter initialized.
- libvirt attach success is not the same as guest enumeration. When the device
  was flaky, the attach succeeded but the guest never brought the radio up. A
  guest-agent enumeration check would close this gap; not implemented.
- Abnormal release (pulling the dongle or a guest dying) can strand the host
  port. Does not happen on clean detach or clean shutdown. Recovery: reseat,
  sysfs unbind/rebind, or host reboot.
- Clean shutdown returns the adapter on its own via `managed='yes'`. Rule:
  detach before powering down.
- Memory: a 6656 MB guest ceiling on an 8 GB host is safe for capture. Capture
  is light on RAM (14 to 16 percent of ceiling, zero swap), and KVM backs guest
  memory lazily, so the host holds only what the guest touches.

## Architecture (v1.6)

- Debian/XFCE host; KVM/QEMU under libvirt on `qemu:///system`. Directory pool
  at `/var/lib/libvirt/images`. `default` NAT network.
- Python 3 / GTK 3. Shells out to `virsh`, `virt-install`, `virt-viewer`. Reads
  free space directly. Sets `LIBVIRT_DEFAULT_URI` in its own environment.
- Rootless via the `libvirt` group. Per-VM disk usage read from libvirt volume
  reporting, not from the disk files.
- ISO library at `/srv/isos`, relocated in on build, reclaimed on delete.
- Space math: sum ceilings, subtract allocation, compare the shortfall to free
  space, render Safe or Oversubscribed.
- Guests: `host-passthrough` CPU, hidden hypervisor signature.
- Wi-Fi: one USB adapter as a `managed='yes'` live hostdev, one VM at a time.

## Limitations (v1.6)

- No importing of a prebuilt qcow2 disk; the add flow assumes an installer ISO.
- No snapshot or clone workflow in the app.
- No guest-side check that the passed-through adapter actually enumerated.
- One adapter, one VM at a time by design.
