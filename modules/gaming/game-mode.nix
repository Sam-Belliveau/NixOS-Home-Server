{ pkgs, inputs, ... }:
{
  # SteamOS-style Game Mode via Jovian-NixOS. Jovian provides the gamescope
  # session AND a working `steamos-session-select`, replacing the old
  # hand-rolled `loginctl terminate-user` shim that black-screened on NVIDIA
  # when handing the display back to a greeter.
  imports = [ inputs.jovian.nixosModules.default ];

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
}
