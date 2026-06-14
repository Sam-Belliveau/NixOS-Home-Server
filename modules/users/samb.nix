{ config, pkgs, ... }:
{
  users.users.samb = {
    isNormalUser = true;
    uid = 1000;
    description = "Sam Belliveau";
    extraGroups = [
      "wheel"
      "networkmanager"
      "gamelib"
      "video"
      "render"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."samb/hashedPassword".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5pAk9+R4kC8ru/n9hz+hWhjixqsp/JwkuzT+JCvwuu samb@Mac"
    ];
  };

  programs.zsh.enable = true;
}
