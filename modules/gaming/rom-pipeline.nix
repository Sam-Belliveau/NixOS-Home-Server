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
  # Kept as a fallback; the live kiosks now use firefox-kiosk (below), since
  # Chrome gets NO hardware video decode on NVIDIA (nvidia-vaapi-driver is
  # Firefox-only) -- which is why the YouTube kiosk was stuck on software
  # decode at 30fps.
  chromeKiosk = pkgs.writeShellScriptBin "chrome-kiosk" ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    exec /run/current-system/sw/bin/google-chrome-stable \
      --use-gl=egl --no-first-run --no-default-browser-check \
      "$@"
  '';

  # Per-profile prefs for the Firefox kiosk. Firefox + nvidia-vaapi-driver is
  # the *only* documented-working HW video decode path on NVIDIA (the driver
  # explicitly refuses Chrome), and our nvidia.nix already ships the matching
  # env (LIBVA_DRIVER_NAME=nvidia, NVD_BACKEND=direct).
  firefoxKioskPrefs = pkgs.writeText "firefox-kiosk-user.js" ''
    // --- NVIDIA VA-API hardware video decode (nvidia-vaapi-driver) ---
    user_pref("media.ffmpeg.vaapi.enabled", true);
    user_pref("media.rdd-ffmpeg.enabled", true);
    user_pref("media.hardware-video-decoding.force-enabled", true); // FF137+
    user_pref("gfx.x11-egl.force-enabled", true);   // VA-API needs EGL on XWayland
    user_pref("widget.dmabuf.force-enabled", true);
    // The RTX 2070 SUPER (Turing) has no AV1 NVDEC, so AV1 would decode on the
    // CPU. Disabling it makes YouTube fall back to VP9, which Turing decodes in
    // hardware. Revisit if this box ever gets an Ampere+ GPU.
    user_pref("media.av1.enabled", false);

    // --- Kiosk hygiene: no prompts, updates, telemetry or crash-restore ---
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.aboutConfig.showWarning", false);
    user_pref("app.update.auto", false);
    user_pref("app.update.enabled", false);
    user_pref("datareporting.policy.dataSubmissionEnabled", false);
    user_pref("datareporting.healthreport.uploadEnabled", false);
    user_pref("browser.sessionstore.resume_from_crash", false);
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("full-screen-api.warning.timeout", 0);
  '';

  # Launcher for browser "smart-TV" apps, Firefox edition. Same XWayland
  # constraint as chrome-kiosk (forced via MOZ_ENABLE_WAYLAND=0). Firefox has no
  # --user-agent flag, so the UA override is written into a per-app profile's
  # user.js. Usage: firefox-kiosk <profile-name> <url> [user-agent]
  firefoxKiosk = pkgs.writeShellScriptBin "firefox-kiosk" ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    profile="$1"; url="$2"; ua="''${3:-}"
    dir="$HOME/.local/share/firefox-kiosk/$profile"
    mkdir -p "$dir"
    # Rewrite prefs every launch so edits to firefoxKioskPrefs always take hold.
    install -m644 ${firefoxKioskPrefs} "$dir/user.js"
    if [ -n "$ua" ]; then
      printf 'user_pref("general.useragent.override", "%s");\n' "$ua" >> "$dir/user.js"
    fi
    # XWayland (gamescope shows X11 reliably) + RDD sandbox off so the decoder
    # process can reach the NVIDIA libs.
    export MOZ_ENABLE_WAYLAND=0
    export MOZ_DISABLE_RDD_SANDBOX=1
    export LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct
    exec /run/current-system/sw/bin/firefox \
      --profile "$dir" --no-remote --kiosk "$url"
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
      # MUST match rom-import's LAUNCH_WRAPPER: a shortcut's appid (which names
      # its art files) is crc32(Exe+name), and the import writes Exe as the
      # wrapper. Computing appids here without the wrapper would file every
      # banner under an appid no shortcut has, so none would ever show.
      export LAUNCH_WRAPPER=/run/current-system/sw/bin/steam-app-launch
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
          # PS3 disc -> route it into the ps3/ system folder no matter where the
          # archive was dropped, since the '${"$"}{title}/PS3_GAME/USRDIR/EBOOT.BIN'
          # parser only scans ${romRoot}/ps3. (PS3_GAME is an unambiguous marker;
          # loose ROMs can't be auto-sorted this way because an extension like
          # .iso is shared across PS2/PSP/Xbox/GameCube/Wii.) Keep PS3_GAME and
          # its siblings (e.g. PS3_DISC.SFB) together under a per-game folder.
          dest="${romRoot}/ps3/$stem"
          mkdir -p "${romRoot}/ps3"
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
    firefoxKiosk
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
