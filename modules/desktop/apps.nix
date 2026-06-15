{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vesktop
    google-chrome
  ];
}
