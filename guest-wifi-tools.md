# Guest Wi-Fi Mode Toolkit

Guest-side monitor/managed toggle that runs without a password on every switch.
Companion to the Sandbox Manager host app.

## The problem

Setting monitor mode needs `CAP_NET_ADMIN`, which normally means root. A naive
guest toggle self-elevates, so every switch prompts for the sudo password.

airgeddon does not have this problem because it runs as one root process: you
authenticate once at launch and every mode switch inside it is free. Reading its
source confirms two things. It hard-requires root (its permission check exits
otherwise), and it switches mode with plain `iw`/`ip` rather than `airmon-ng`,
which is what avoids stomping NetworkManager. So airgeddon's trick is no-airmon,
not no-root. The no-password behavior here comes from a scoped sudoers rule, not
from airgeddon.

## What gets installed

Run `install-wifi-mode.sh` once in the guest. It writes four things:

- `/usr/local/sbin/wifi-switch`: root-owned helper. Brings the interface down,
  sets the type with `iw`, brings it up, and toggles the NetworkManager
  per-device managed flag so NM does not revert the change. Accepts `monitor`,
  `managed`, `toggle`, `status`. Owned root, mode 0755: anyone runs it, nobody
  edits it.
- `/etc/sudoers.d/wifi-switch`: no-password rule scoped to that one helper and
  the installing user. Validated with `visudo -c` before install.
- `~/bin/wifi-mode.sh`: wrapper. Calls the helper through the rule, reports the
  result with a notification. Never edits the launcher.
- `~/Desktop/wifi-mode.desktop`: icon, `Terminal=false`.

The installer scopes the sudoers rule to whoever runs it, finds the real Desktop
directory via `xdg-user-dir`, checks for `iw`/`ip`/`sudo`, defaults to `wlan0`
(override with `WIFI_IFACE`), and is safe to re-run.

## Install and use

```bash
bash install-wifi-mode.sh    # once; prompts for sudo password one time
```

```bash
~/bin/wifi-mode.sh           # toggle
~/bin/wifi-mode.sh monitor   # force monitor
~/bin/wifi-mode.sh managed   # force managed
~/bin/wifi-mode.sh status    # report
```

Or click the icon: no terminal, a notification shows the new mode. First click
may hit XFCE's "Allow Launching" once; grant it and it sticks.

## Design choices

- The helper is root-owned and not user-writable. This is the security hinge: a
  no-password rule pointing at a user-writable script is a full root-escalation
  path. Do not loosen it.
- The rule is scoped to one binary and one user. No shell, no general `iw`/`ip`,
  no other users.
- `iw`/`ip`, not `airmon-ng`, so NetworkManager is not stomped.
- NetworkManager is told (per-device managed flag), not killed, so the guest's
  `eth0` stays up through the switch.
- The wrapper reports state by notification and never edits the launcher.

## The XFCE trust nag

An earlier wrapper rewrote the launcher's label on every toggle to show the
current mode. That re-triggered XFCE's "untrusted launcher" prompt every time,
because XFCE marks a `.desktop` untrusted whenever its contents change. Fix:
stop editing the launcher; report state by notification instead. The launcher is
now static, so you grant trust once and it holds. Cost: the icon label does not
change. If you want a changing label, bind the toggle to a keyboard shortcut
instead of a desktop icon; shortcuts run the command directly with no trust
check.

## Assumptions

- XFCE for the icon and the trust model. The helper, rule, and wrapper are
  environment-agnostic.
- Requires `iw`, `ip`, `sudo`. Optional: `nmcli` (skipped if absent),
  `notify-send` (skipped if absent).
- Interface defaults to `wlan0`, override with `WIFI_IFACE`.
- Idempotent.

## Where it fits

v1.6's passthrough hands the physical adapter into the guest. This makes using
it inside the guest a one-click, no-password operation. Together they cover the
wireless path: attach on the host, flip to monitor with one guest click,
capture, flip back, detach, tear down.
