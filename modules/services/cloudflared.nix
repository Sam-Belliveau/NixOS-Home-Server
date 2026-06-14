{ lib, config, ... }:
let
  cfg = config.myServices.cloudflared;
in
{
  options.myServices.cloudflared.enable = lib.mkEnableOption "Cloudflare tunnel";

  config = lib.mkIf cfg.enable {
    # Real tunnel UUID is filled at install; ingress hostnames are added per use.
    services.cloudflared = {
      enable = true;
      tunnels."00000000-0000-0000-0000-000000000000" = {
        credentialsFile = config.sops.secrets."cloudflared/credentials".path;
        default = "http_status:404";
        ingress = {
        };
      };
    };
  };
}
