{ config, pkgs, ... }:
let
  romRoot = "/games/roms";

  reimport = pkgs.writeShellApplication {
    name = "srm-reimport";
    runtimeInputs = [
      pkgs.steam-rom-manager
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      # Steam must be closed or SRM corrupts shortcuts.vdf.
      if pgrep -x gamescope >/dev/null; then
        echo "gamescope running; deferring import"
        exit 0
      fi
      STEAMGRIDDB_API_KEY="$(cat ${config.sops.secrets."steamgriddb/apikey".path})"
      export STEAMGRIDDB_API_KEY
      steam-rom-manager enable --all
      steam-rom-manager add
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.steam-rom-manager
    reimport
  ];

  # Import dropped ROMs as Steam shortcuts with SteamGridDB artwork. Runs as the
  # Game Mode user so SRM writes that account's library.
  systemd.services.rom-import = {
    serviceConfig = {
      Type = "oneshot";
      User = "steam";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 15";
      ExecStart = "${reimport}/bin/srm-reimport";
    };
  };

  # Watch the drop folder (recursively) and trigger a re-import on any change.
  systemd.services.rom-watch = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = pkgs.writeShellScript "rom-watch" ''
        ${pkgs.inotify-tools}/bin/inotifywait -m -r \
          -e close_write -e moved_to -e delete "${romRoot}" |
        while read -r _; do
          ${pkgs.systemd}/bin/systemctl start --no-block rom-import.service
        done
      '';
    };
  };
}
