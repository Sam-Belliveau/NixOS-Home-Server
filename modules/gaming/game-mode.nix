{ pkgs, inputs, ... }:
{
  # SteamOS-style Game Mode via Jovian-NixOS. Jovian provides the gamescope
  # session AND a working `steamos-session-select`, replacing the old
  # hand-rolled `loginctl terminate-user` shim that black-screened on NVIDIA
  # when handing the display back to a greeter.
  imports = [ inputs.jovian.nixosModules.default ];

  # KNOWN LIMITATION: embedded gamescope corrupts 4K output on NVIDIA (bug
  # 5240452, unfixed as of 595.84) -- purple flicker on the bottom of the TV
  # at any 4K mode, SDR or HDR, HDMI or USB-C/DP. Run the TV at 1920x1080@60
  # (clean) and retest 4K on driver bumps. A Plasma-hosted nested-gamescope
  # workaround was tried 2026-08-24 and rejected: it fixed 4K but lost the
  # overlay/guide button, in-session resolution switching, and perf overlays.
  jovian.steam = {
    enable = true;
    autoStart = true; # boot straight into Game Mode
    user = "samb"; # who Game Mode runs/autologins as
    desktopSession = "plasma"; # "Switch to Desktop" -> Plasma 6 (+ Return to Gaming Mode)
  };

  # Steam itself + extras. Jovian owns the gamescope *session*, so we no longer
  # set programs.steam.gamescopeSession or programs.gamescope here (that combo
  # was what built the broken setuid bwrap wrapper).
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extest.enable = true;
    protontricks.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  # No display manager: jovian.steam.autoStart launches Game Mode directly on
  # boot (a traditional DM like SDDM cannot coexist with autoStart), and
  # desktopSession="plasma" starts Plasma when you Switch to Desktop.

  # This box is also the home server: mask suspend at the systemd level so no
  # stray power setting can ever take the services down.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };

  # Apply gamescope convars once its control socket is up:
  #  - hdr_enabled 0: NVIDIA 555+ corrupts embedded-gamescope output at high
  #    modes with HDR engaged (see bug note above), and the living-room TV's
  #    HDR looks bad anyway.
  #  - drm_allow_dynamic_modes_for_external_display 1: makes Steam's refresh
  #    rate picker actually change the display mode on external displays.
  #    Takes effect on the next hotplug/reprobe, so nudge every connector.
  systemd.user.services.gamescope-tweaks = {
    description = "Force gamescope HDR off and allow dynamic display modes";
    wantedBy = [ "gamescope-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    environment.WAYLAND_DISPLAY = "gamescope-0";
    script = ''
      for _ in $(seq 1 60); do
        if ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 0 2>/dev/null; then
          ${pkgs.gamescope}/bin/gamescopectl drm_allow_dynamic_modes_for_external_display 1
          for c in /sys/class/drm/card*-*/status; do
            echo detect | /run/wrappers/bin/sudo -n tee "$c" >/dev/null 2>&1 || true
          done
          exit 0
        fi
        sleep 1
      done
      echo "gamescope control socket never appeared" >&2
      exit 1
    '';
  };
}
