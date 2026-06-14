{ pkgs }:
let
  inherit (pkgs) lib mkShell;

  ldPath = libs: lib.makeLibraryPath (libs ++ [ pkgs.stdenv.cc.cc.lib ]);

  cudaLibs = with pkgs.cudaPackages; [ cuda_cudart libcublas cudnn ];
  cudaTools = with pkgs.cudaPackages; [ cuda_nvcc cuda_cudart libcublas cudnn cuda_nvrtc ];
in
{
  # ── Baseline: always-available formatters + language servers ─────────────
  default = mkShell {
    packages = with pkgs; [ git just direnv nixd nixfmt-rfc-style python3 uv ];
  };

  # ── Python ML: wheels (torch/opencv/…) via uv, made loadable by nix-ld ───
  python-ml = mkShell {
    packages = with pkgs; [ python3 uv ];
    shellHook = ''
      export NIX_LD_LIBRARY_PATH="${ldPath (with pkgs; [ zlib openssl ])}:''${NIX_LD_LIBRARY_PATH:-}"
    '';
  };

  # ── CUDA: pinned toolkit (edit `cudaPackages` → `cudaPackages_12_8` etc.) ─
  cuda = mkShell {
    packages = cudaTools ++ (with pkgs; [ cmake ninja gcc python3 uv ]);
    shellHook = ''
      export CUDA_HOME="${pkgs.cudaPackages.cuda_nvcc}"
      export NIX_LD_LIBRARY_PATH="${ldPath cudaLibs}:''${NIX_LD_LIBRARY_PATH:-}"
    '';
  };

  # ── Gaussian splatting: COLMAP(CUDA) from Nix + nerfstudio/gsplat via uv ──
  gaussian-splat = mkShell {
    packages =
      [ (pkgs.colmap.override { cudaSupport = true; }) ]
      ++ cudaTools
      ++ (with pkgs; [ cmake ninja gcc python3 uv ffmpeg ]);
    shellHook = ''
      export CUDA_HOME="${pkgs.cudaPackages.cuda_nvcc}"
      export NIX_LD_LIBRARY_PATH="${ldPath cudaLibs}:''${NIX_LD_LIBRARY_PATH:-}"
      echo "gaussian-splat: uv venv && uv pip install nerfstudio gsplat"
    '';
  };

  # ── Rust ─────────────────────────────────────────────────────────────────
  rust = mkShell {
    packages = with pkgs; [ rustc cargo clippy rustfmt rust-analyzer pkg-config ];
  };

  # ── C / C++ ────────────────────────────────────────────────────────────-─
  cpp = mkShell {
    packages = with pkgs; [ clang clang-tools cmake ninja lldb gdb ];
    shellHook = "export CMAKE_EXPORT_COMPILE_COMMANDS=ON";
  };
}
