{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager

    ./hardware.nix
    ./disko-os.nix
    ./disko-data.nix
    # ./disko-scratch.nix          # 2TB - DISABLED; read the file header before enabling.

    ../../modules/system
    ../../modules/desktop
    ../../modules/gaming
    ../../modules/dev
    ../../modules/services
    ../../modules/users
  ];

  networking.hostName = "samb-tower";

  # Service manifest - one switch per service
  myServices = {
    homeAssistant.enable = true;
    cloudflared.enable = true;
    jellyfin.enable = true;
    syncthing.enable = true;
    adguardhome.enable = true;
    homepage.enable = true;
  };

  # home-manager: both login users
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.samb = import ../../home/samb.nix;
    users.steam = import ../../home/steam.nix;
  };

  system.stateVersion = "26.05";
}
