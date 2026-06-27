{ pkgs }:
let
  lib = pkgs.lib;

  # CUDA 12.6. The spec pinned 12.4 (to pair with a cu124 torch wheel), but 12.4
  # has since been dropped from this flake's pinned nixpkgs — only 12.6/12.8/12.9
  # and 13.x remain. 12.6 is the closest surviving set and shares torch's CUDA
  # *major* (12), so a cu124/cu126 torch wheel still builds gsplat's kernels:
  # PyTorch only errors on a CUDA *major* mismatch, it warns on a minor one.
  cuda = pkgs.cudaPackages_12_6;

  # nvcc's host compiler: NixOS' default gcc is too new for nvcc, so use the exact
  # gcc cudaPackages_12_6 certifies (gcc12 has been removed from nixpkgs).
  hostcc = cuda.backendStdenv.cc;

  # Libraries the pip-installed wheels (torch, opencv, rawpy, …) dlopen at run
  # time. Foreign wheels under a uv-managed standalone Python resolve these via
  # NIX_LD_LIBRARY_PATH (nix-ld); a venv built from *this* nixpkgs Python
  # resolves them via LD_LIBRARY_PATH. We export both so either layout works.
  wheelLibs = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    zstd
    glib
    libGL
    glibc
    xorg.libX11
    libxcrypt-legacy
  ];

  cudaLibs = with cuda; [
    cuda_cudart
    libcublas
    cudnn
    cuda_nvrtc
  ];

  ldPath = lib.makeLibraryPath (cudaLibs ++ wheelLibs);
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

  # COLMAP (CUDA) + toolchain to pip-install nerfstudio/gsplat/splatfacto-w into
  # a venv where capturegraph-lib is importable. devShells are NOT part of the
  # system closure, so none of this CUDA build runs during nixos-rebuild — only
  # when you `nix develop .#gaussian-splat`.
  #
  # One-time, inside this shell, in that venv:
  #   pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cu124
  #   pip install nerfstudio==1.1.5 gsplat==1.4.0
  #   pip install "git+https://github.com/KevinXu02/splatfacto-w"
  # gsplat compiles its CUDA kernels here — the only step that exercises
  # nvcc + gcc12 + CUDA_HOME, so if Tier 2 breaks, it breaks there.
  gaussian-splat = pkgs.mkShell {
    packages = [
      (pkgs.colmap.override { cudaSupport = true; })
      hostcc
    ]
    ++ (with cuda; [
      cuda_nvcc
      cuda_cudart
      cuda_cccl
      libcublas
      cudnn
      cuda_nvrtc
    ])
    ++ (with pkgs; [
      cmake
      ninja
      git
      python311
      uv
      ffmpeg
    ]);

    shellHook = ''
      export CUDA_HOME="${cuda.cuda_nvcc}"
      export CUDAHOSTCXX="${hostcc}/bin/g++"
      export CC="${hostcc}/bin/gcc"
      export CXX="${hostcc}/bin/g++"

      # libcuda.so ships with the NVIDIA driver, not with any nix package; on
      # NixOS it lives at /run/opengl-driver/lib. torch.cuda.is_available() needs
      # it at run time; the cuda libs above are needed at gsplat build time.
      export LD_LIBRARY_PATH="${ldPath}:/run/opengl-driver/lib:''${LD_LIBRARY_PATH:-}"
      export NIX_LD_LIBRARY_PATH="${ldPath}:/run/opengl-driver/lib:''${NIX_LD_LIBRARY_PATH:-}"
    '';
  };
}
