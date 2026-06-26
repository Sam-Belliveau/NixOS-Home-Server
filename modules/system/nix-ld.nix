{ pkgs, ... }:
{
  # Run unpatched dynamic binaries: VS Code Remote server, pip/uv wheels, conda.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
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
    ];
  };
}
