{
  description = "python-ml — uv venv + nix-ld-friendly binary wheels";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python3 uv ];
        shellHook = ''
          export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (
            with pkgs; [ stdenv.cc.cc.lib zlib openssl ]
          )}:''${NIX_LD_LIBRARY_PATH:-}"
        '';
      };
    };
}
