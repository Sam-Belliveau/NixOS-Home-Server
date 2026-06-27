{ ... }:
{
  imports = [
    ./cli.nix
    ./toolchains.nix
    ./python.nix
    ./reconstruction.nix
    ./cuda.nix
    ./ml-wheels.nix
  ];
}
