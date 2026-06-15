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
    capSysNice = true;
  };

  # Autologin into the gamescope Steam session; log out to choose Plasma.
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    autoLogin = {
      enable = true;
      user = "steam";
    };
    defaultSession = "steam";
  };

  environment.systemPackages = [ sessionSelect ];
}
