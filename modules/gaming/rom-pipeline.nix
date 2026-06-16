{ pkgs, ... }:
let
  romRoot = "/games/roms";

  # Headless shortcut generator. Steam ROM Manager is an Electron app that hangs
  # when run without a display (e.g. at boot), so instead of driving SRM we read
  # its declarative config and write shortcuts.vdf ourselves. SRM stays installed
  # for managing artwork from the desktop; this owns the automated import.
  pyEnv = pkgs.python3.withPackages (ps: [ ps.vdf ]);

  # Steam injects its Ubuntu steam-runtime LD_LIBRARY_PATH into every launched
  # app, which makes Nix-built binaries fail to load libs (e.g. coreutils want
  # libattr "ATTR_1.3" but get Steam's stale libattr.so.1) - so the launch dies
  # before the app ever starts. Every generated shortcut runs through this
  # wrapper, which scrubs the env with shell builtins only (invoking `env` or
  # any coreutil here would itself fail under the bad path) and then execs.
  launcher = pkgs.writeShellScriptBin "steam-app-launch" ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    exec "$@"
  '';

  # Launcher for browser "smart-TV" apps. Must stay on XWayland: gamescope's
  # Game Mode only reliably displays X11 clients, and a native-Wayland Chrome
  # launched through Steam never shows its window. --use-gl=egl avoids the GBM
  # init error ("dri_gbm.so: Permission denied") the default backend hits here.
  # Per-app args (profile, user-agent, --kiosk, URL) come from the caller.
  chromeKiosk = pkgs.writeShellScriptBin "chrome-kiosk" ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    exec /run/current-system/sw/bin/google-chrome-stable \
      --use-gl=egl --no-first-run --no-default-browser-check \
      "$@"
  '';

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
      # Stable path (survives rebuilds); the sync re-runs each boot anyway.
      export LAUNCH_WRAPPER=/run/current-system/sw/bin/steam-app-launch
      exec python3 ${./steam-shortcuts.py}
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.steam-rom-manager # desktop GUI, kept for artwork management
    launcher
    chromeKiosk
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
