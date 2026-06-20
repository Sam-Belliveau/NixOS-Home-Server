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
      "input" # controllers in Game Mode (previously via the steam user)
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."samb/hashedPassword".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5pAk9+R4kC8ru/n9hz+hWhjixqsp/JwkuzT+JCvwuu samb@Mac"
    ];
  };

  programs.zsh.enable = true;

  # Passwordless sudo for samb so the box can be fully managed and rebooted over
  # SSH (key-only auth from this one authorized laptop; single-user home server).
  # Note: sudo can't key off the connection origin, so this applies to the samb
  # account everywhere, not strictly to SSH sessions.
  security.sudo.extraRules = [
    {
      users = [ "samb" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
