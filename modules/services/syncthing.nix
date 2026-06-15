{ lib, config, ... }:
let
  cfg = config.myServices.syncthing;
in
{
  options.myServices.syncthing.enable = lib.mkEnableOption "Syncthing";

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "samb";
      group = "users";
      dataDir = "/srv/syncthing";
      configDir = "/srv/syncthing/.config";
      # Sync/discovery ports (22000, 21027) open for LAN + internet peers.
      openDefaultPorts = true;
      # Listen on all interfaces but DON'T open :8384 in the firewall, so the
      # GUI is reachable only over Tailscale (trustedInterfaces). Set a GUI
      # password in Syncthing since it's no longer localhost-only.
      guiAddress = "0.0.0.0:8384";
    };
  };
}
