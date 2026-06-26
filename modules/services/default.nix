{ ... }:
{
  imports = [
    ./openssh.nix
    ./tailscale.nix
    ./cloudflared.nix
    ./home-assistant.nix
    ./jellyfin.nix
    ./syncthing.nix
    ./adguardhome.nix
    ./homepage.nix
    ./capturegraph.nix
    ./courtyard-worker.nix
  ];
}
