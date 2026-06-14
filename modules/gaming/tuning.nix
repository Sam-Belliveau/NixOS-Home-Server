{ pkgs, ... }:
{
  programs.gamemode.enable = true;

  # Prevent a whole-box freeze under memory pressure (big games / builds).
  services.earlyoom.enable = true;

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
    "kernel.split_lock_mitigate" = 0;
  };

  environment.systemPackages = [ pkgs.mangohud ];
}
