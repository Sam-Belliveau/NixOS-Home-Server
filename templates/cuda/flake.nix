{
  description = "cuda — pinned cudaPackages + nvcc toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      cuda = pkgs.cudaPackages; # swap to cudaPackages_12_8 / _13_x to pin
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages =
          (with cuda; [ cuda_nvcc cuda_cudart libcublas cudnn cuda_nvrtc ])
          ++ (with pkgs; [ cmake ninja gcc python3 uv ]);
        shellHook = ''
          export CUDA_HOME="${cuda.cuda_nvcc}"
          export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (
            (with cuda; [ cuda_cudart libcublas cudnn ]) ++ [ pkgs.stdenv.cc.cc.lib ]
          )}:''${NIX_LD_LIBRARY_PATH:-}"
        '';
      };
    };
}
