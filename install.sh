#!/usr/bin/env bash
# Run from the booted NixOS installer. Partitions both disks (DESTRUCTIVE on the
# 1TB OS and 4TB data disks only), installs the persisted host key, and installs
# NixOS. Re-runnable for a clean reinstall.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Optional commit/branch/tag to install (e.g. ./install.sh eae5679).
# Defaults to the latest commit on the default branch.
REPO="github:Sam-Belliveau/NixOS-Home-Server"
REF="${1:-}"
FLAKE="$REPO${REF:+/$REF}#samb-tower"

# tarball-ttl = 0 forces Nix to re-resolve the mutable github: ref on every run.
# Without it, Nix reuses a cached revision for up to an hour, which previously
# reinstalled a stale closure even after a fresh push.
export NIX_CONFIG="experimental-features = nix-command flakes
tarball-ttl = 0"

echo ">> Partition + format (DESTROYS the 1TB OS and 4TB data disks)"
nix run github:nix-community/disko -- --mode destroy,format,mount --flake "$FLAKE"

echo ">> Install the host SSH key (sops age identity)"
install -d -m 0755 /mnt/etc/ssh
install -m 0600 "$HERE/ssh_host_ed25519_key" /mnt/etc/ssh/ssh_host_ed25519_key
install -m 0644 "$HERE/ssh_host_ed25519_key.pub" /mnt/etc/ssh/ssh_host_ed25519_key.pub

echo ">> Install NixOS"
nixos-install --flake "$FLAKE" --no-root-passwd

echo ">> Done. Reboot and remove the USB."
