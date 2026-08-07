# Changelog

All notable changes to this project are documented here. The format follows
Keep a Changelog, and releases are numbered by feature milestone.

## [1.6] - 2026-08-06
### Added
- USB Wi-Fi passthrough for the Atheros AR9271 (USB ID `0cf3:9271`): a per-sandbox
  Attach Wi-Fi / Detach Wi-Fi button, one physical adapter moved between VMs one
  at a time, matched by `vendor:product` so a replug that renumbers the device
  never breaks the match, with live state shown in each row.
- Companion tooling: `wifi-vm.sh` (host-side attach/detach/status) and a guest-side
  passwordless monitor/managed toggle (`wifi-mode.sh`, `install-wifi-mode.sh`).
### Notes
- Passthrough uses a `managed='yes'` hostdev, live only. A clean shutdown returns
  the adapter to the host on its own. Detach before powering a guest down to avoid
  a stranded port on abnormal release.

## [1.5] - 2026-08-05
### Added
- Self-reclaiming ISO library: deleting a sandbox removes its installer image when
  no other sandbox references it.
- "Purge unused ISOs" button to clear orphaned images.

## [1.4] - 2026-08-05
### Fixed
- Relocation hardening: best-effort `chmod` (libvirt's dynamic chown can leave an
  ISO owned by `libvirt-qemu`, which is used as-is rather than failing the build);
  skip re-moving an image already present in the library.

## [1.3] - 2026-08-05
### Added
- Scrollable, selectable, copyable log (replaces the single-line status label).
- Automatic relocation of a local ISO into the library on build, so building from
  a file anywhere avoids the hypervisor read-permission wall.

## [1.2] - 2026-08-05
### Added
- Drag-and-drop of an ISO file onto the ISO field.

## [1.1] - 2026-08-05
### Added
- Accept a local file path or a URL in the ISO field, with a Browse button.
- ISO library at `/srv/isos`, outside the VM pool, ending installer-image
  duplication and keeping the pool for VM disks only.

## [1.0] - 2026-08-04
### Added
- Initial GTK control panel: live space dashboard with a Safe/Oversubscribed
  verdict, sandbox list with Launch and Delete, add-a-sandbox from an ISO URL,
  and a fully rootless model routed through libvirt.
### Fixed
- Crash parsing `vol-info --bytes` output (the trailing "bytes" token).
