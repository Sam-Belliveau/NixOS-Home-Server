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
    gamescopeSession = {
      enable = true;
      env.ENABLE_GAMESCOPE_WSI = "1";
    };
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
