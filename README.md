# NixOS-Home-Server (`samb-tower`)

A single NixOS 26.05 machine that is two things at once:

- a **couch gaming console** - boots straight into Steam Game Mode on the TV, controller-first, with standalone emulators and a drop-a-ROM-and-it-appears pipeline; and
- a **headless dev / home server** - reached over SSH and Tailscale, running Home Assistant, Jellyfin, Syncthing, AdGuard Home, a Cloudflare tunnel, Sunshine streaming, and a comprehensive dev toolchain.

The whole machine is declared here. There is no manual post-install fiddling beyond placing secrets once.

## Hardware

| Part | Value |
|------|-------|
| Machine | System76 Thelio (BIOS F15a Z5) |
| CPU | Intel i9-9900K (8c/16t) |
| RAM | 32 GB |
| GPU | NVIDIA RTX 2070 SUPER (sole GPU) |
| OS disk | 1 TB NVMe (Samsung 970 EVO Plus) |
| Data disk | 4 TB SATA SSD (Samsung 870 QVO) |
| Scratch | 2 TB NVMe - see [HARVEST.md](HARVEST.md), disabled by default |

## Layout

| | |
|---|---|
| `flake.nix` | inputs (nixpkgs, home-manager, disko, sops-nix) and the `samb-tower` system |
| `hosts/samb-tower/` | host config, hardware facts, disko disk layout |
| `modules/system/` | nix settings, boot, swap, nix-ld, auto-upgrade, secrets |
| `modules/desktop/` | Plasma 6, fonts |
| `modules/gaming/` | NVIDIA, Game Mode session, controllers, Sunshine, emulators, ROM pipeline |
| `modules/dev/` | compilers, language runtimes, Python tooling, TeX |
| `modules/services/` | sshd, tailscale, cloudflared, Home Assistant, Jellyfin, Syncthing, AdGuard, Homepage |
| `modules/users/` | the `steam` and `samb` accounts and the shared `gamelib` group |
| `home/` | per-user home-manager (shell, prompt, git, VS Code) |

Disks: the 1 TB holds `/` and `/nix` on btrfs plus a swapfile; the 4 TB holds `/home`, `/games`, and `/srv` on btrfs. zram is the primary swap. Services keep their data under `/srv`; the Steam library and ROMs live under `/games`.

## Install

The 64 GB USB stick is a reusable installer: the NixOS 26.05 ISO plus a `SAMOS-SECRETS` partition holding this machine's SSH host key (its sops age identity) and `install.sh`.

Boot the stick, then:

```bash
sudo bash /run/media/*/SAMOS-SECRETS/install.sh
```

`install.sh` partitions both disks with disko (destructive: 1 TB + 4 TB only), places the host key, runs `nixos-install`, and reboots. sops-nix decrypts the committed secrets on first boot using that host key, so a reinstall needs nothing re-harvested.

Manual equivalent:

```bash
sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
  --flake github:Sam-Belliveau/NixOS-Home-Server#samb-tower
# place ssh_host_ed25519_key{,.pub} into /mnt/etc/ssh/ (0600 / 0644)
sudo nixos-install --flake github:Sam-Belliveau/NixOS-Home-Server#samb-tower
sudo reboot
```

## Day to day

```bash
# Apply changes now (from a checkout, or by URL):
sudo nixos-rebuild switch --flake .#samb-tower

# Roll back: pick the previous generation in the boot menu, or:
sudo nixos-rebuild switch --rollback
```

Pushed changes are picked up by a nightly auto-upgrade. nixpkgs itself is advanced by a scheduled CI workflow that commits `flake.lock`, so every update is reviewable in git history.

**Automatic reboots** are off by default. To let the box reboot itself after kernel/NVIDIA updates, set `allowReboots = true` in `modules/system/auto-upgrade.nix`.

## Services

| Service | Port | Notes |
|---------|------|-------|
| SSH | 22 | key-only; the sole recovery path |
| Home Assistant | 8123 | data in `/srv/home-assistant` |
| Jellyfin | 8096 | NVENC via the Jellyfin dashboard |
| AdGuard Home | 3000 (UI), 53 (DNS) | disables the resolved stub |
| Homepage | 8082 | service + system dashboard |
| Syncthing | 8384 (UI over Tailscale) | runs as `samb` |
| Sunshine | 47990 (UI) | stream to Moonlight clients |

## ROMs

Drop a ROM into `/games/roms/<system>/` (e.g. `gamecube`, `ps2`, `n64`). A watcher imports it into Steam with SteamGridDB artwork using the standalone emulators; it appears in Game Mode after the next Steam restart. Parser definitions live in `home/steam/srm/userConfigurations.json`.

## Recovery

The NVIDIA card is the only GPU, so a broken graphical boot is recovered over SSH (always on, key-only). The machine's SSH host identity is persisted on the install USB, so it is stable across reinstalls.
