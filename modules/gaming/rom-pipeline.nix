{ config, pkgs, ... }:
let
  romRoot = "/games/roms";

  reimport = pkgs.writeShellApplication {
    name = "srm-reimport";
    runtimeInputs = [
      pkgs.steam-rom-manager
      pkgs.xvfb-run # SRM is Electron; needs a display even for the `add` CLI
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      # Steam must be closed or SRM corrupts shortcuts.vdf. Guard against both
      # Game Mode (gamescope) and the desktop Steam client.
      if pgrep -x gamescope >/dev/null || pgrep -x steam >/dev/null; then
        echo "Steam/gamescope running; deferring import"
        exit 0
      fi
      # Nothing to write to until Steam has been signed into once.
      if ! ls -d "$HOME"/.steam/steam/userdata/*/ >/dev/null 2>&1; then
        echo "Steam not signed in yet; skipping import"
        exit 0
      fi
      STEAMGRIDDB_API_KEY="$(cat ${config.sops.secrets."steamgriddb/apikey".path})"
      export STEAMGRIDDB_API_KEY
      # SRM bundles Electron, so even the `add` CLI boots Chromium and needs a
      # display. This service runs at boot (Steam closed) *before* any
      # compositor exists, so without a display Electron segfaults (status 139)
      # and never writes shortcuts.vdf. Hand it a throwaway virtual X display.
      xvfb-run -a steam-rom-manager enable --all
      xvfb-run -a steam-rom-manager add
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.steam-rom-manager
    reimport
  ];

  # Import ROMs + app shortcuts (Vesktop, Chrome) as the Game Mode user, before
  # the session starts. Runs each boot; SteamGridDB artwork is cached after first.
  systemd.services.rom-import = {
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "samb";
      TimeoutStartSec = 120;
      ExecStart = "${reimport}/bin/srm-reimport";
    };
  };

  # Live drops: import ROMs added while the box is up.
  systemd.services.rom-watch = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = pkgs.writeShellScript "rom-watch" ''
        ${pkgs.inotify-tools}/bin/inotifywait -m -r \
          -e close_write -e moved_to -e delete "${romRoot}" |
        while read -r _; do
          ${pkgs.coreutils}/bin/sleep 15
          ${pkgs.systemd}/bin/systemctl start --no-block rom-import.service
        done
      '';
    };
  };
}
