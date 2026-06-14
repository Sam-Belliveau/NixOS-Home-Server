{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    liberation_ttf
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];
}
