{ lib, config, ... }:
let
  cfg = config.myServices.adguardhome;
in
{
  options.myServices.adguardhome.enable = lib.mkEnableOption "AdGuard Home DNS";

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;
      port = 3000;
    };

    # DNS must stay open to the LAN (this box is the LAN resolver).
    # The web UI on :3000 is deliberately NOT opened to the LAN; it's reachable
    # only over Tailscale (see trustedInterfaces in the tailscale module).
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # Free port 53 from the systemd-resolved stub listener.
    services.resolved.enable = lib.mkForce false;
  };
}
