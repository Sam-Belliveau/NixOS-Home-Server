# Hardware harvest and install-time notes

Captured from the machine before the NixOS install. This is the home for context
that deliberately stays out of the `.nix` files.

## Machine

- System76 Thelio, BIOS `F15a Z5`.
- Intel i9-9900K (8c/16t), GenuineIntel -> Intel microcode.
- 32 GB RAM. zram + a 16 GB swapfile; no hibernation.
- NVIDIA RTX 2070 SUPER (TU104, Turing) at PCI `01:00.0`. Sole GPU; no Intel iGPU
  enumerated, so SSH is the only recovery path if a graphical boot fails.

## Disks (stable by-id paths)

| Role | by-id |
|------|-------|
| OS, 1 TB NVMe | `nvme-Samsung_SSD_970_EVO_Plus_1TB_S59ANJ0N209883H` |
| Data, 4 TB SATA | `ata-Samsung_SSD_870_QVO_4TB_S5VYNG0NC01406M` |
| Scratch, 2 TB NVMe | `nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNJ0N102070D` |

## The 2 TB drive

It currently enumerates as `state=dead`, `size=0`, while still showing a stale
partition table. Both NVMe drives run the same firmware (`2B2QEXM7`) yet only the
2 TB is dead, which rules out a firmware-version difference. Most likely cause: the
drive drops off the bus under deep NVMe APST power states (matches the
"intermittent recognition" history). The fix is already applied for all NVMe in
`hardware.nix`:

```
nvme_core.default_ps_max_latency_us=0
```

Secondary possibility: a genuinely failing unit. So the 2 TB is left out of the
install (`hosts/samb-tower/disko-scratch.nix` is not imported). Adopt it only after
it survives several cold/warm boots with the APST param:

```bash
ls -l /dev/disk/by-id | grep 970_EVO_Plus_2TB   # path present across boots?
# then, to adopt as expendable scratch (DESTRUCTIVE on that disk only):
#   - import ./disko-scratch.nix in hosts/samb-tower/default.nix
#   - set: samb.scratch.enable = true;
#   - sudo nix run github:nix-community/disko -- --mode disko \
#       --flake .#samb-tower    # operates only on declared disks
```

If it stays dead, RMA it. Nothing irreplaceable ever lives there.

## Secrets to harvest (go into the encrypted store, see SECRETS.md)

- **cloudflared**: the existing tunnel credentials JSON and its tunnel UUID.
  ```bash
  sudo ls /etc/cloudflared /root/.cloudflared ~/.cloudflared 2>/dev/null
  # copy <UUID>.json into sops; put the real UUID into
  #   modules/services/cloudflared.nix (tunnels."<UUID>") and add ingress hosts.
  ```
- **tailscale**: create an auth key in the admin console -> sops `tailscale/authkey`.
  First-time interactive join also works: `sudo tailscale up`.
- **SteamGridDB**: an API key from steamgriddb.com -> sops `steamgriddb/apikey`.
- **samb password**: `mkpasswd -m yescrypt` -> sops `samb/hashedPassword`.

## Controllers

The wake-from-controller udev rule needs BIOS support: enable **ErP / Wake on USB**
in the F15a setup. Xbox, DualShock4 (Sony `054c`), and Stadia (Google `18d1`) are
covered by Steam Input plus the udev rules in `modules/gaming/controllers.nix`.

## ROM pipeline binaries

`home/steam/srm/userConfigurations.json` points each parser at
`/run/current-system/sw/bin/<emulator>`. Confirm the exact binary names after the
first build and correct the JSON if needed:

```bash
ls /run/current-system/sw/bin | grep -iE 'dolphin|pcsx2|ares|melon|mgba|ppsspp|rpcs3|cemu|azahar|xemu'
```
