#!/usr/bin/env bash
# setup.sh: one-time host setup for Sandbox Manager.
# Creates the libvirt storage pool and ISO library, ensures the default network
# is up, and adds you to the libvirt/kvm groups. Idempotent; safe to re-run.
set -euo pipefail

URI="qemu:///system"
POOL="vm-storage"
POOL_DIR="/var/lib/libvirt/images"
ISO_LIB="/srv/isos"
NEED_RELOGIN=0

echo "== Sandbox Manager host setup =="

for c in virsh virt-install; do
  command -v "$c" >/dev/null 2>&1 || {
    echo "missing: $c  (install: sudo apt install virtinst libvirt-clients)"; exit 1; }
done

# groups
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
  echo "Adding $USER to libvirt,kvm ..."
  sudo usermod -aG libvirt,kvm "$USER"
  NEED_RELOGIN=1
fi

# daemon + default network (privileged, so use sudo virsh)
sudo systemctl enable --now libvirtd
sudo virsh net-autostart default >/dev/null 2>&1 || true
sudo virsh net-start default    >/dev/null 2>&1 || true

# storage pool (privileged define so it works even before re-login)
if ! sudo virsh -c "$URI" pool-info "$POOL" >/dev/null 2>&1; then
  echo "Creating pool $POOL at $POOL_DIR ..."
  sudo virsh -c "$URI" pool-define-as "$POOL" dir --target "$POOL_DIR"
  sudo virsh -c "$URI" pool-build "$POOL"
  sudo virsh -c "$URI" pool-start "$POOL"
  sudo virsh -c "$URI" pool-autostart "$POOL"
else
  echo "Pool $POOL already exists."
fi

# ISO library outside the pool, readable by the hypervisor
if [ ! -d "$ISO_LIB" ]; then
  echo "Creating ISO library $ISO_LIB ..."
  sudo mkdir -p "$ISO_LIB"
  sudo chown "$USER:$USER" "$ISO_LIB"
  chmod 755 "$ISO_LIB"
else
  echo "ISO library $ISO_LIB already exists."
fi

echo "Done."
if [ "$NEED_RELOGIN" = 1 ]; then
  echo "IMPORTANT: log out and back in for libvirt/kvm group membership to take effect."
fi
