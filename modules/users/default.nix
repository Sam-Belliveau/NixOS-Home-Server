{ ... }:
{
  imports = [
    ./groups.nix
    ./samb.nix
  ];

  users.mutableUsers = false;
}
