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
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
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

  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [ sessionSelect ];
}
