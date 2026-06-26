{ pkgs, ... }:
{
  # Tier 1 of the courtyard-reconstruction stack: COLMAP on the system PATH so
  # registration.py (pose refinement / SfM) and the optional courtyard worker
  # can shell out to `colmap` without first entering a devShell.
  #
  # CPU build on purpose: it's in the binary cache (instant, and can't fail a
  # nixos-rebuild), and the spec says CPU is fine for ~230 frames. The
  # CUDA-accelerated build is available interactively via
  # `nix develop .#gaussian-splat` when you want the GPU speedup.
  environment.systemPackages = [
    pkgs.colmap
    # pkgs.glomap   # faster global SfM — uncomment to also put it on the PATH
  ];
}
