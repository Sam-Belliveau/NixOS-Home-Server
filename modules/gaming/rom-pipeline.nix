{ pkgs, ... }:
let
  romRoot = "/games/roms";

  # Headless shortcut generator. Steam ROM Manager is an Electron app that hangs
  # when run without a display (e.g. at boot), so instead of driving SRM we read
  # its declarative config and write shortcuts.vdf ourselves. SRM stays installed
  # for managing artwork from the desktop; this owns the automated import.
  pyEnv = pkgs.python3.withPackages (ps: [ ps.vdf ]);

  reimport = pkgs.writeShellApplication {
    name = "steam-shortcuts-sync";
    runtimeInputs = [
      pyEnv
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      # Steam rewrites shortcuts.vdf on exit and would clobber our changes, so
      # only write while it's closed. This service runs at boot, before the
      # Game Mode session starts.
      if pgrep -x gamescope >/dev/null || pgrep -x steam >/dev/null; then
        echo "Steam/gamescope running; deferring shortcut sync"
        exit 0
      fi
      # Nothing to write to until Steam has been signed into once.
      if ! ls -d "$HOME"/.steam/steam/userdata/*/ >/dev/null 2>&1; then
        echo "Steam not signed in yet; skipping sync"
        exit 0
      fi
      exec python3 ${./steam-shortcuts.py}
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.steam-rom-manager # desktop GUI, kept for artwork management
    reimport
  ];

  # Write app + ROM shortcuts as the Game Mode user, before the session starts.
  # Runs each boot; cheap (globs folders + writes a binary file, no network).
  systemd.services.rom-import = {
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "samb";
      TimeoutStartSec = 120;
      ExecStart = "${reimport}/bin/steam-shortcuts-sync";
    };
  };

  # Live drops: re-sync when ROMs are added while the box is up. (Takes effect on
  # the next boot/Steam restart, since Steam owns shortcuts.vdf while running.)
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
