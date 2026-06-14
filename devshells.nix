{ pkgs }:
let
  cuda = pkgs.cudaPackages;
  ldPath = pkgs.lib.makeLibraryPath (
    (with cuda; [
      cuda_cudart
      libcublas
      cudnn
    ])
    ++ [ pkgs.stdenv.cc.cc.lib ]
  );
in
{
  default = pkgs.mkShell {
    packages = with pkgs; [
      git
      just
      direnv
      nixd
      nixfmt
    ];
  };

  # COLMAP (CUDA) + toolchain for nerfstudio/gsplat via uv.
  gaussian-splat = pkgs.mkShell {
    packages = [
      (pkgs.colmap.override { cudaSupport = true; })
    ]
    ++ (with cuda; [
      cuda_nvcc
      cuda_cudart
      libcublas
      cudnn
      cuda_nvrtc
    ])
    ++ (with pkgs; [
      cmake
      ninja
      gcc
      python3
      uv
      ffmpeg
    ]);
    shellHook = ''
      export CUDA_HOME="${cuda.cuda_nvcc}"
      export NIX_LD_LIBRARY_PATH="${ldPath}:''${NIX_LD_LIBRARY_PATH:-}"
    '';
  };
}
