{ pkgs, ... }:
{
  # Photogrammetry / Structure-from-Motion tooling, available system-wide as a
  # generic library — not tied to any one project. COLMAP is a general SfM + MVS
  # engine; anything doing pose estimation or sparse reconstruction can shell out
  # to `colmap` without first entering a devShell.
  #
  # CUDA build, for GPU SIFT extraction/matching and GPU bundle adjustment. CUDA
  # is unfree, so no binary cache holds it: every nixpkgs bump recompiles COLMAP
  # during the rebuild. Compiling for the RTX 2070 SUPER's architecture alone
  # (sm_75) and skipping the test suite keeps that compile short.
  environment.systemPackages = [
    (pkgs.colmap.override {
      cudaSupport = true;
      cudaCapabilities = [ "7.5" ];
      enableTests = false;
    })
    # pkgs.glomap   # faster global SfM — uncomment to also expose it
  ];
}
