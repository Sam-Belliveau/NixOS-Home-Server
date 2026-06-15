{ lib, config, ... }:
let
  cfg = config.myServices.homepage;
in
{
  options.myServices.homepage.enable = lib.mkEnableOption "Homepage dashboard";

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = 8082;

      # Not opened to the LAN; reachable only over Tailscale
      # (see trustedInterfaces in the tailscale module).
      #
      # Homepage does strict Host-header validation; the default only allows
      # localhost. Reaching it by hostname (README links, Tailscale) needs the
      # name allow-listed too. Add the MagicDNS name if you hit it that way,
      # e.g. "samb-tower.<tailnet>.ts.net:8082".
      allowedHosts = "samb-tower:8082,localhost:8082,127.0.0.1:8082";

      settings.title = "samb-tower";

      services = [
        {
          "Media" = [
            {
              "Jellyfin" = {
                href = "http://samb-tower:8096";
              };
            }
          ];
        }
        {
          "Home" = [
            {
              "Home Assistant" = {
                href = "http://samb-tower:8123";
              };
            }
          ];
        }
        {
          "Network" = [
            {
              "AdGuard Home" = {
                href = "http://samb-tower:3000";
              };
            }
          ];
        }
      ];

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
      ];
    };
  };
}
