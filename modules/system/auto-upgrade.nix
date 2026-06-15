{ lib, ... }:
let
  # true lets the box reboot itself after kernel/NVIDIA updates.
  allowReboots = false;
in
{
  # nixpkgs is bumped by the update.yml CI workflow; this rebuilds the pinned flake.
  system.autoUpgrade = {
    enable = true;
    flake = "github:Sam-Belliveau/NixOS-Home-Server#samb-tower";
    operation = "switch";
    dates = "daily";
    randomizedDelaySec = "45min";
    persistent = true;
    allowReboot = allowReboots;
    rebootWindow = lib.mkIf allowReboots {
      lower = "03:00";
      upper = "05:00";
    };
  };

  # Also run the upgrade ~5 min after every boot, so rebooting pulls the latest
  # config too — not just the daily timer. The randomizedDelaySec above also
  # jitters this run, so a reboot lands an update within roughly 5-50 min.
  systemd.timers.nixos-upgrade.timerConfig.OnBootSec = "5min";
}
