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

  # SteamGridDB artwork for every shortcut (ROMs + apps/websites). Separate from
  # the shortcut sync because it needs the network and an API key, and unlike
  # shortcuts.vdf the grid/ folder is safe to write while Steam is running
  # (Steam picks up new art on its next restart). The key is the sops secret.
  artworkSync = pkgs.writeShellApplication {
    name = "steam-artwork-sync";
    runtimeInputs = [
      pyEnv
      pkgs.coreutils
    ];
    text = ''
      if ! ls -d "$HOME"/.steam/steam/userdata/*/ >/dev/null 2>&1; then
        echo "Steam not signed in yet; skipping artwork"
        exit 0
      fi
      export STEAMGRIDDB_KEY_FILE=/run/secrets/steamgriddb/apikey
      exec python3 ${./steam-shortcuts.py} --artwork
    '';
  };

  # Auto-unpack dropped archives so packed ROMs (e.g. a PS3 game shipped as a
  # .7z) are seen by the parsers. Idempotent: a ".unpacked" marker beside each
  # archive stops re-extraction, and the original is left in place.
  romExtract = pkgs.writeShellApplication {
    name = "rom-extract";
    runtimeInputs = [
      pkgs._7zz # official 7-Zip: handles 7z/zip/rar/tar
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      find "${romRoot}" -type f \
        \( -iname '*.7z' -o -iname '*.zip' -o -iname '*.rar' \
           -o -iname '*.tar' -o -iname '*.tar.gz' -o -iname '*.tgz' \) -print0 |
      while IFS= read -r -d "" archive; do
        marker="$archive.unpacked"
        [ -e "$marker" ] && continue

        dir=$(dirname "$archive")
        base=$(basename "$archive")
        stem="''${base%.*}"     # drop the extension
        stem="''${stem%.tar}"   # ...and the inner .tar of a .tar.gz
        tmp=$(mktemp -d "$dir/.extract.XXXXXX")

        echo "rom-extract: unpacking $archive"
        if ! 7zz x -y -bso0 -bsp0 -o"$tmp" "$archive"; then
          echo "rom-extract: FAILED $archive"
          rm -rf "$tmp"
          continue
        fi

        # Locate a PS3 disc tree if there is one (-print -quit takes the first
        # hit and avoids a SIGPIPE under pipefail). Detect it *before* any
        # flattening so we don't mistake a top-level PS3_GAME for a wrapper.
        ps3game=$(find "$tmp" -maxdepth 3 -iname PS3_GAME -type d -print -quit)

        if [ -n "$ps3game" ]; then
          # PS3 disc -> keep PS3_GAME (and siblings like PS3_DISC.SFB) under a
          # per-game folder so the '${"$"}{title}/PS3_GAME/USRDIR/EBOOT.BIN'
          # parser matches, whether or not the archive wrapped it in a folder.
          dest="$dir/$stem"
          rm -rf "$dest"
          mkdir -p "$dest"
          find "$(dirname "$ps3game")" -mindepth 1 -maxdepth 1 \
            -exec mv -t "$dest" {} +
        else
          # Loose ROM file(s) -> drop straight into the system folder where the
          # file-based parsers look, collapsing a single redundant wrapper
          # directory (Game/Game.iso -> Game.iso) on the way.
          mapfile -t top < <(find "$tmp" -mindepth 1 -maxdepth 1)
          if [ "''${#top[@]}" -eq 1 ] && [ -d "''${top[0]}" ]; then
            root="''${top[0]}"
          else
            root="$tmp"
          fi
          find "$root" -mindepth 1 -maxdepth 1 -exec mv -t "$dir" {} +
        fi

        rm -rf "$tmp"
        touch "$marker"
        echo "rom-extract: done $archive"
      done
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.steam-rom-manager # desktop GUI, kept for manual artwork tweaks
    launcher
    chromeKiosk
    reimport
    artworkSync
    romExtract
  ];

  # Unpack any dropped archives. Kept off the boot critical path (no
  # before=display-manager): a big PS3 .7z shouldn't delay the session. When it
  # finishes it kicks the import so the freshly-unpacked game gets a shortcut.
  systemd.services.rom-extract = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "samb";
      TimeoutStartSec = 3600; # PS3 images can be tens of GB
      ExecStart = "${romExtract}/bin/rom-extract";
      # '+' runs this as root: a User=samb service can't start a system unit
      # (polkit denies it from a session-less context).
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl start --no-block rom-import.service";
    };
  };

  # Write app + ROM shortcuts as the Game Mode user, before the session starts.
  # Runs each boot; cheap (globs folders + writes a binary file, no network).
  # On success it kicks the artwork pass.
  systemd.services.rom-import = {
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "samb";
      TimeoutStartSec = 120;
      ExecStart = "${reimport}/bin/steam-shortcuts-sync";
      # '+' runs this as root (see rom-extract above).
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl start --no-block rom-artwork.service";
    };
  };

  # SteamGridDB artwork for every shortcut. Needs the network, so it runs after
  # network-online and never blocks the boot into Game Mode. Idempotent: it
  # skips apps that already have art, so re-runs are cheap.
  systemd.services.rom-artwork = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "rom-import.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "samb";
      TimeoutStartSec = 600;
      ExecStart = "${artworkSync}/bin/steam-artwork-sync";
    };
  };

  # Live drops: when ROMs/archives are added while the box is up, run the
  # unpack -> import -> artwork chain. (Shortcuts take effect on the next
  # Steam restart, since Steam owns shortcuts.vdf while running.)
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
          ${pkgs.systemd}/bin/systemctl start --no-block rom-extract.service
        done
      '';
    };
  };
}
