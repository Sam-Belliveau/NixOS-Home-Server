{ ... }:
{
  imports = [
    ./cli.nix
    ./documents.nix
    ./toolchains.nix
    ./python.nix
    ./reconstruction.nix
    ./cuda.nix
    ./ml-wheels.nix
  ];
}
