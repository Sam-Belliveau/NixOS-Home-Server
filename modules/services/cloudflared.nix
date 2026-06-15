{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.myServices.cloudflared;
  # Pass the token via the environment, not argv: /proc/<pid>/cmdline is
  # world-readable (visible in `ps aux`), but /proc/<pid>/environ is owner-only.
  # cloudflared reads TUNNEL_TOKEN when no --token flag is given.
  run = pkgs.writeShellScript "cloudflared-run" ''
    export TUNNEL_TOKEN="$(cat ${config.sops.secrets."cloudflared/token".path})"
    exec ${pkgs.cloudflared}/bin/cloudflared --no-autoupdate tunnel run
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
