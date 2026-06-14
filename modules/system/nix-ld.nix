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
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXi
      xorg.libXrandr
      xorg.libXcursor
      xorg.libXfixes
      fontconfig
      freetype
      ffmpeg
    ];
  };
}
