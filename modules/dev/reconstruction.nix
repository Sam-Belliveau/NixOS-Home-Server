{ pkgs, ... }:
{
  # Photogrammetry / Structure-from-Motion tooling, available system-wide as a
  # generic library — not tied to any one project. COLMAP is a general SfM + MVS
  # engine; anything doing pose estimation or sparse reconstruction can shell out
  # to `colmap` without first entering a devShell.
  #
  # CPU build on purpose: it's in the binary cache (instant, and can't fail a
  # nixos-rebuild). The CUDA-accelerated COLMAP plus the full GPU Gaussian-splat
  # Python toolchain (nvcc, cudnn, nerfstudio/gsplat) live in the `gaussian-splat`
  # devShell — `nix develop .#gaussian-splat` — so none of that heavy CUDA closure
  # is ever pulled into the system.
  environment.systemPackages = [
    pkgs.colmap
    # pkgs.glomap   # faster global SfM — uncomment to also expose it
  ];
}
