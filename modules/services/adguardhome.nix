{ lib, config, ... }:
let
  cfg = config.myServices.adguardhome;
in
{
  options.myServices.adguardhome.enable = lib.mkEnableOption "AdGuard Home DNS";

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;
      openFirewall = true;
      port = 3000;
    };

    # openFirewall covers the web UI only; DNS needs port 53 opened explicitly.
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # Free port 53 from the systemd-resolved stub listener.
    services.resolved.enable = lib.mkForce false;
  };
}
