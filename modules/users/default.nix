{ ... }:
{
  imports = [
    ./groups.nix
    ./samb.nix
    ./steam.nix
  ];

  users.mutableUsers = false;
}
