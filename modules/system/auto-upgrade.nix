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
}
