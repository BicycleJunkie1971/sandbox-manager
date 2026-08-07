# Sandbox Manager

A point-and-click GTK control panel for disposable KVM/libvirt Linux sandboxes.
Build throwaway VMs from an ISO or URL, launch or delete them in one click, and
see a live disk-oversubscription verdict for your encrypted volume. Includes a
self-reclaiming ISO library and a one-adapter USB Wi-Fi passthrough for wireless
work. Runs rootless: no sudo prompts.


---

## Why this exists

General-purpose VM front ends (virt-manager, GNOME Boxes) manage machines.
Sandbox Manager is built for a narrower job: **disposable** sandboxes you spin
up, use, and throw away, on a single laptop, without leaving installer images or
guesswork behind. Three things set it apart from the general tools:

- **A live oversubscription verdict.** It continuously meters your
  LUKS-backed pool and answers the question those tools do not: *if every
  sandbox grew to its ceiling at once, would you run out of disk?* Green
  "Safe" or red "Oversubscribed," updated every few seconds. This catches
  sparse-qcow2 growth before it fills the disk by surprise.
- **A self-reclaiming ISO library.** Installer images live outside the VM
  pool and are removed automatically when the last sandbox using them is
  deleted, so they never quietly hoard encrypted space.
- **Integrated single-adapter Wi-Fi passthrough.** Hand a physical USB Wi-Fi
  radio to a running sandbox for monitor-mode and injection work an emulated
  NIC cannot do, and take it back with one click.

All of it runs as your normal user. Privileged work goes through libvirt, which
you already have access to via the `libvirt` group, so the app never calls
`sudo`.

---

## Screenshot

![Sandbox Manager](Screenshot_2026-08-06_17-41-56.png)

---

## Features

- Build a sandbox from an ISO **URL** or a **local file** (Browse or drag and
  drop).
- One-click **Launch** and **Delete** for every sandbox.
- **Live space dashboard**: free space, provisioned ceilings, actual on-disk
  allocation, and a Safe / Oversubscribed verdict.
- **Self-reclaiming ISO library** with a manual "Purge unused ISOs" button.
- **USB Wi-Fi passthrough** per sandbox, one physical adapter moved between VMs
  one at a time, with live state shown in each row.
- Guests are built to **look like bare metal** (`host-passthrough` CPU,
  hidden hypervisor signature) so software inside does not trivially detect
  virtualization.
- **Rootless**: all privileged operations go through libvirt, no `sudo`
  prompts in normal use.

---

## Requirements

- Linux with **KVM/QEMU** and **libvirt** (`qemu:///system`).
- **Python 3** with **GTK 3** bindings.
- Packages (Debian/Kali/Ubuntu names): `python3-gi`, `gir1.2-gtk-3.0`,
  `virtinst`, `virt-viewer`, `libvirt-clients`, `libvirt-daemon-system`. All of
  these are present if you already have `virt-manager` installed.
- Your user must be in the **`libvirt`** and **`kvm`** groups.

Tested on Debian 13 with XFCE. Other distributions and desktops are expected to
work but are not yet verified. The desktop-icon behavior assumes XFCE.

---

## One-time setup

The app assumes a small amount of libvirt substrate exists. A `setup.sh` can
automate this; the manual steps are:

```bash
# 1. install dependencies (skip any already present)
sudo apt install -y python3-gi gir1.2-gtk-3.0 virtinst virt-viewer \
                    libvirt-clients libvirt-daemon-system

# 2. join the libvirt and kvm groups, then LOG OUT AND BACK IN
sudo usermod -aG libvirt,kvm "$USER"

# 3. make sure the daemon is running and the default network is up
sudo systemctl enable --now libvirtd
sudo virsh net-autostart default
sudo virsh net-start default 2>/dev/null || true

# 4. create the storage pool the app expects (name: vm-storage)
virsh -c qemu:///system pool-define-as vm-storage dir --target /var/lib/libvirt/images
virsh -c qemu:///system pool-build vm-storage
virsh -c qemu:///system pool-start vm-storage
virsh -c qemu:///system pool-autostart vm-storage

# 5. create the ISO library outside the pool, readable by the hypervisor
sudo mkdir -p /srv/isos
sudo chown "$USER:$USER" /srv/isos
chmod 755 /srv/isos
```

`/srv` is world-traversable and `/srv/isos` is owned by you, so the QEMU
process can read installer images there directly, with no ACLs and without
exposing your home directory or duplicating images into the encrypted pool.

---

## Running it

```bash
python3 sandbox-manager-v1_6.py
```

For a desktop icon, create a `.desktop` launcher with `Exec=python3
/full/path/sandbox-manager-v1_6.py`, `Terminal=false`, and
`StartupNotify=false`. On XFCE, right-click the icon once and choose "Allow
Launching."

---

## Configuration

The tunable constants live at the top of the script. Edit them for your setup:

| Constant | Default | Meaning |
|---|---|---|
| `POOL` | `vm-storage` | libvirt storage pool holding VM disks |
| `POOL_DIR` | `/var/lib/libvirt/images` | on-disk path of that pool |
| `URI` | `qemu:///system` | libvirt instance |
| `ISO_LIB` | `/srv/isos` | ISO library, outside the pool |
| `WIFI_USBID` | `0cf3:9271` | USB Wi-Fi adapter to pass through (Atheros AR9271) |

If you use a different Wi-Fi adapter, change `WIFI_USBID` to your device's
`vendor:product` ID from `lsusb`.

---

## Usage

**Build a sandbox.** Enter a name, paste an ISO URL or Browse/drag a local ISO,
set RAM and disk, and click Download & Build. The disk size is a ceiling, not a
reservation; a sparse qcow2 only uses real space as the guest fills it. Size it
to what the guest will actually need. Heavy distributions (Kali, Parrot) want
40 GB or more.

**Launch / Delete.** Each sandbox row has Launch and Delete. Delete removes the
VM, its disk, and its ISO if no other sandbox needs it.

**Watch the space verdict.** The dashboard shows a green "Safe" or red
"Oversubscribed" line. Oversubscribed means your combined ceilings exceed real
free space, so filling every box would run you out. It is a warning, not a
failure; a single guest can still run out of its own ceiling independently.

**Purge unused ISOs.** Clears any installer image in the library that no current
sandbox references.

---

## USB Wi-Fi passthrough

Each running sandbox row has an **Attach Wi-Fi** / **Detach Wi-Fi** button. The
adapter is matched by `vendor:product`, so a replug that renumbers the device
never breaks the match. Only one VM holds the adapter at a time; attaching to a
new VM detaches it from the current holder first.

The attach is live only (never written into the persistent domain config), and
uses libvirt `managed='yes'`, so a clean guest shutdown returns the radio to the
host on its own. **Detach before you power a guest down** to avoid a stranded
port on abnormal release.

### Host side

`wifi-vm.sh` is a standalone command-line equivalent of the in-app button, with
`attach`, `detach`, and `status`, keyed to the same `vendor:product` so a replug
never breaks it. Use it for scripted or headless workflows:

```bash
./wifi-vm.sh attach <vm-name>
./wifi-vm.sh detach <vm-name>
./wifi-vm.sh status
```

### Guest side: passwordless monitor/managed toggle

Inside the sandbox, `guest-tools/install-wifi-mode.sh` sets up a one-click
monitor/managed toggle that runs **without a password on every switch**. Normally
setting monitor mode needs root, so a naive toggle prompts for a sudo password
every time. This installs a small root-owned helper plus a scoped, no-password
sudoers rule for that one helper, so you authenticate once at install and then
flip modes freely, the same way airgeddon holds root for its whole session.

Run once, inside the guest:

```bash
bash install-wifi-mode.sh
```

It installs four pieces: a root-owned `wifi-switch` helper (plain `iw`/`ip`, so it
does not stomp NetworkManager), a `sudoers.d` rule scoped to that helper and your
user, a `~/bin/wifi-mode.sh` wrapper, and an XFCE desktop icon. The installer is
generic: it scopes the rule to whoever runs it, finds the real Desktop directory,
checks for `iw`/`ip`/`sudo`, defaults to `wlan0` (override with `WIFI_IFACE`), and
is safe to re-run.

After install, no password ever again:

```bash
~/bin/wifi-mode.sh            # toggle monitor <-> managed
~/bin/wifi-mode.sh monitor    # force monitor
~/bin/wifi-mode.sh managed    # force managed
~/bin/wifi-mode.sh status     # report current mode
```

Or click the desktop icon: no terminal opens, and a notification reports the new
mode. The security of the no-password rule depends on `wifi-switch` staying
root-owned and not user-writable; the installer sets this, do not loosen it.

Full design notes are in [`guest-wifi-tools.md`](guest-wifi-tools.md).

---

## Security and trust model

Stated plainly so you can judge it:

- **Being in the `libvirt` group is effectively root-equivalent on the host.**
  That is how the app avoids `sudo`. Treat membership accordingly.
- **Guest disks inherit the host's encryption at rest** because they live on
  the LUKS-backed pool. They are not separately encrypted from the host.
- **The guest Wi-Fi toggle grants passwordless sudo to one fixed helper.** Its
  safety depends on that helper being root-owned and not user-writable; the
  installer sets this and it must not be loosened.
- **Hypervisor hiding defeats casual detection, not a determined adversary.**
  Timing and firmware artifacts can still betray a VM. Claim "not trivially
  detectable," never "undetectable."

---

## Legal and ethical use

The Wi-Fi passthrough and monitor-mode tooling are for wireless testing on
networks and equipment you **own or are explicitly authorized to test**.
Capturing or interfering with networks without permission is illegal in most
jurisdictions. Use this responsibly.

---

## How it compares

Sandbox Manager overlaps in spirit with virt-manager, GNOME Boxes, and
Quickemu, and with Qubes OS on disposability. What is hard to find in a single
lightweight tool is its specific combination: a desktop oversubscription
verdict, a self-reclaiming ISO library, and integrated single-adapter
passthrough with a pay-once guest toggle. See the landscape survey
for a feature-by-feature comparison.

---

## Documentation

- [`DOCUMENTATION.md`](DOCUMENTATION.md): full project record,
  inception through v1.6, with the design decisions and field notes.
- [`guest-wifi-tools.md`](guest-wifi-tools.md): the guest-side Wi-Fi
  mode toolkit.
- [`landscape-survey.md`](landscape-survey.md): how this compares to
  existing tools and what is arguably novel.

---

## License

MIT. See [`LICENSE`](LICENSE).
