{ ... }:
{
  imports = [
    ./nix-settings.nix
    ./boot.nix
    ./swap.nix
    ./nix-ld.nix
    ./auto-upgrade.nix
    ./secrets.nix
  ];
}
