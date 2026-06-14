#!/usr/bin/env bash
# Run from the booted NixOS installer. Partitions both disks (DESTRUCTIVE on the
# 1TB OS and 4TB data disks only), installs the persisted host key, and installs
# NixOS. Re-runnable for a clean reinstall.
set -euo pipefail

FLAKE="github:Sam-Belliveau/NixOS-Home-Server#samb-tower"
HERE="$(cd "$(dirname "$0")" && pwd)"

export NIX_CONFIG="experimental-features = nix-command flakes"

echo ">> Partition + format (DESTROYS the 1TB OS and 4TB data disks)"
nix run github:nix-community/disko -- --mode destroy,format,mount --flake "$FLAKE"

echo ">> Install the host SSH key (sops age identity)"
install -d -m 0755 /mnt/etc/ssh
install -m 0600 "$HERE/ssh_host_ed25519_key" /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 "$HERE/ssh_host_ed25519_key.pub" /mnt/etc/ssh/ssh_host_ed25519_key.pub

echo ">> Install NixOS"
nixos-install --flake "$FLAKE" --no-root-passwd

echo ">> Done. Reboot and remove the USB."
