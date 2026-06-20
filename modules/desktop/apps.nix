{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vesktop
    google-chrome
    # Firefox is the kiosk browser: it's the only browser the nvidia-vaapi-driver
    # supports, so it's the one that actually gets HW video decode here. See the
    # firefox-kiosk launcher in modules/gaming/rom-pipeline.nix.
    firefox
  ];
}
