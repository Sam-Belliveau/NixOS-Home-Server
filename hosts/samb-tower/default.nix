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

  # Static resolvers, always present in /etc/resolv.conf ahead of whatever
  # DHCP hands NetworkManager. DNS on this box must not depend on any one
  # daemon or lease being healthy (see modules/services/tailscale.nix).
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
    "1.0.0.1"
  ];

  # Service manifest - one switch per service
  myServices = {
    # 2026-09-06: Home Assistant (+ matter-server), Jellyfin and qBittorrent
    # switched off to keep the box lean and reboots fast. State is untouched
    # (/srv/home-assistant, /var/lib/jellyfin, qbittorrent profile); flip back
    # to true to bring one back.
    homeAssistant.enable = false;
    cloudflared.enable = true;
    jellyfin.enable = false;
    qbittorrent.enable = false;
    syncthing.enable = true;
    homepage.enable = true;
    capturegraph.enable = true;
  };

  # home-manager for samb
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.samb = import ../../home/samb.nix;
  };

  system.stateVersion = "26.05";
}
