{ pkgs, config, ... }:
let
  # Expose only the NVIDIA driver's libcuda (the userspace driver stub) to nix-ld,
  # not the whole driver tree, so pip CUDA wheels (torch) resolve libcuda.so.1
  # without shadowing the system libGL for other foreign binaries. The driver ships
  # libcuda; everything else CUDA is bundled in the torch wheel.
  libcuda = pkgs.runCommand "nix-ld-libcuda" { } ''
    mkdir -p $out/lib
    ln -s ${config.hardware.nvidia.package}/lib/libcuda.so* $out/lib/
  '';
in
{
  # Run unpatched dynamic binaries: VS Code Remote server, pip/uv wheels, conda.
  programs.nix-ld = {
    enable = true;
    libraries = [ libcuda ] ++ (with pkgs; [
      stdenv.cc.cc.lib
      zlib
      zstd
      xz
      bzip2
      openssl
      libffi
      ncurses
      readline
      curl
      libssh
      expat
      icu
      libuuid
      util-linux
      libGL
      libglvnd
      glib
      libx11
      libxext
      libxrender
      libxi
      libxrandr
      libxcursor
      libxfixes
      fontconfig
      freetype
      ffmpeg
      # Python ML wheels (torch/opencv/rawpy) want these: libcrypt.so.1 from the
      # legacy libxcrypt, plus glibc's own lib dir for the odd direct dlopen.
      glibc
      libxcrypt-legacy
    ]);
  };
}
