{ pkgs, ... }:
let
  # Steam's "Switch to Desktop" runs this; ending the session shows the picker.
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    exec ${pkgs.systemd}/bin/loginctl terminate-user "$(id -u)"
  '';
in
{
  programs.steam = {
    enable = true;
    # NOTE: do NOT set env.ENABLE_GAMESCOPE_WSI here. It leaks into gamescope's
    # own process, loading the WSI Vulkan layer into the compositor itself, which
    # segfaults on NVIDIA (595 / gamescope 3.16.23) and crashes the session.
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    extest.enable = true;
    protontricks.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamescope = {
    enable = true;
    # Keep false: with gamescopeSession.enable, capSysNice makes nixpkgs build a
    # setuid bwrap wrapper around bubblewrap 0.11.2 (which dropped setuid
    # support), and that broken wrapper blocks Steam from launching at all.
    capSysNice = false;
  };

  # Autologin samb into the gamescope Steam session ("steam" here is the session
  # name, not a user). Switch to Desktop / log out to pick Plasma.
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    autoLogin = {
      enable = true;
      user = "samb";
    };
    defaultSession = "steam";
  };

  environment.systemPackages = [ sessionSelect ];
}
