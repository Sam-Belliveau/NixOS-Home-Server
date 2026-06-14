{
  description = "gaussian-splat — COLMAP(CUDA) + nerfstudio/gsplat via uv";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      cuda = pkgs.cudaPackages;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages =
          [ (pkgs.colmap.override { cudaSupport = true; }) ]
          ++ (with cuda; [ cuda_nvcc cuda_cudart libcublas cudnn cuda_nvrtc ])
          ++ (with pkgs; [ cmake ninja gcc python3 uv ffmpeg ]);
        shellHook = ''
          export CUDA_HOME="${cuda.cuda_nvcc}"
          export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (
            (with cuda; [ cuda_cudart libcublas cudnn ]) ++ [ pkgs.stdenv.cc.cc.lib ]
          )}:''${NIX_LD_LIBRARY_PATH:-}"
          echo "uv venv && uv pip install nerfstudio gsplat"
        '';
      };
    };
}
