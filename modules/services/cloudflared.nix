{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.myServices.cloudflared;
  run = pkgs.writeShellScript "cloudflared-run" ''
    exec ${pkgs.cloudflared}/bin/cloudflared --no-autoupdate tunnel run \
      --token "$(cat ${config.sops.secrets."cloudflared/token".path})"
  '';
in
{
  options.myServices.cloudflared.enable = lib.mkEnableOption "Cloudflare tunnel";

  config = lib.mkIf cfg.enable {
    # Token-managed tunnel; ingress is configured in the Cloudflare dashboard.
    systemd.services.cloudflared = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = run;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
