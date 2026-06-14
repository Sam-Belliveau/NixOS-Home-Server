{ lib, config, ... }:
let
  cfg = config.myServices.homepage;
in
{
  options.myServices.homepage.enable = lib.mkEnableOption "Homepage dashboard";

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
      listenPort = 8082;

      settings.title = "samb-tower";

      services = [
        { "Media" = [ { "Jellyfin" = { href = "http://samb-tower:8096"; }; } ]; }
        { "Home" = [ { "Home Assistant" = { href = "http://samb-tower:8123"; }; } ]; }
        { "Network" = [ { "AdGuard Home" = { href = "http://samb-tower:3000"; }; } ]; }
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
