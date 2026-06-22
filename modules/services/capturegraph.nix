{ lib, pkgs, config, ... }:
let
  cfg = config.myServices.capturegraph;

  # The CaptureGraph research checkout lives in samb's home. The actual launch
  # logic (flags, mounts, optional docs rebuild) lives in a gitignored
  # autorun.sh *inside that checkout*, so changing how the server starts is a
  # one-line edit to that script — no nixos-rebuild needed. This unit only
  # points systemd at the script and keeps it running across boots.
  home = "/home/samb";
  repo = "${home}/Programming/Research/capturegraph";
  autorun = "${repo}/autorun.sh";
in
{
  options.myServices.capturegraph.enable =
    lib.mkEnableOption "CaptureGraph capture server (autostart via autorun.sh)";

  config = lib.mkIf cfg.enable {
    systemd.services.capturegraph = {
      description = "CaptureGraph server — docs at /pydocs, interactive at /interactive";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # The launch script is gitignored and lives only in samb's home checkout,
      # so it never travels with the GitHub-flake build. If it's missing (e.g.
      # a fresh disko reprovision before the checkout is restored), skip the
      # unit cleanly instead of crash-looping it every RestartSec.
      unitConfig.ConditionPathExists = autorun;

      # Give the unit a sane HOME (the uv venv reads ~/.cache, ~/.local) and a
      # minimal PATH for the few coreutils the script and venv shell out to.
      environment.HOME = home;
      path = [ pkgs.coreutils ];

      serviceConfig = {
        User = "samb";
        Group = "users";
        WorkingDirectory = repo;
        # Run the script with the store's bash directly, so startup doesn't
        # depend on the unit's PATH resolving a shell. autorun.sh calls the uv
        # venv's binaries by absolute path; it runs the server in the
        # foreground here (it detects $INVOCATION_ID) so systemd can supervise,
        # log to the journal, and restart it.
        ExecStart = "${pkgs.bash}/bin/bash ${autorun}";
        Restart = "on-failure";
        RestartSec = 5;

        # samb has passwordless sudo (modules/users/samb.nix) and this server
        # listens on the network, so a compromise must not be able to escalate:
        # block setuid/sudo for the service and everything it spawns.
        NoNewPrivileges = true;
      };
    };

    # No firewall port is opened: the server (bound on 0.0.0.0:4433, see
    # capturegraph-server/test/config.toml) is reached two ways, both of which
    # bypass the LAN/WAN firewall —
    #   * Cloudflare tunnel: cloudflared connects to 127.0.0.1:4433 over
    #     loopback; the public hostname → service ingress is configured in the
    #     Cloudflare dashboard (see modules/services/cloudflared.nix).
    #   * Tailscale: tailscale0 is a trusted interface (modules/services/
    #     tailscale.nix), so the bound port is reachable over the tailnet.
    # UPnP is disabled in config.toml so the box never self-forwards 4433 to the
    # open internet on boot. To also expose it on the raw LAN, add:
    #   networking.firewall.allowedTCPPorts = [ 4433 ];
  };
}
