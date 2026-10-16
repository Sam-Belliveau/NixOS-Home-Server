{ ... }:
{
  imports = [
    ./openssh.nix
    ./tailscale.nix
    ./cloudflared.nix
    ./home-assistant.nix
    ./jellyfin.nix
    ./qbittorrent.nix
    ./syncthing.nix
    ./homepage.nix
    ./capturegraph.nix
    ./claude-remote-control.nix
  ];
}
