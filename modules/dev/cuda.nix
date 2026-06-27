{ pkgs, ... }:
let
  # Match the gaussian-splat devShell: CUDA 12.6 is the newest toolkit in this
  # flake's pinned nixpkgs that shares a torch cu12x wheel's CUDA *major* (12),
  # which is all gsplat's kernel build requires.
  cuda = pkgs.cudaPackages_12_6;
in
{
  # Generic CUDA build toolchain — libraries, not a project. nvcc + CUDA headers
  # and libs (the combined `cudatoolkit` is a single derivation, so it can't collide
  # in the system buildEnv) for compiling CUDA Python extensions such as gsplat into
  # a venv, available on the PATH without entering a devShell.
  #
  # Only the *build* toolkit lives here: pip torch wheels bundle their own CUDA
  # runtime, and the NVIDIA driver's libcuda.so is provided at run time from
  # /run/opengl-driver/lib — so no CUDA runtime libraries are added to the system.
  environment.systemPackages = [ cuda.cudatoolkit ];

  environment.sessionVariables = {
    CUDA_HOME = "${cuda.cudatoolkit}";
    # nvcc's host compiler must be older than NixOS' default gcc; use the exact one
    # cudaPackages_12_6 certifies. CUDAHOSTCXX only affects nvcc (CUDA) compilation,
    # so exporting it globally is safe — it doesn't change ordinary C/C++ builds.
    CUDAHOSTCXX = "${cuda.backendStdenv.cc}/bin/g++";
  };
}
