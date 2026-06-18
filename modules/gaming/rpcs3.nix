# rpcs3 from the official upstream AppImage, run inside an FHS sandbox.
#
# Why not pkgs.rpcs3: the nixpkgs package vendors wolfSSL/Fusion as shared libs
# but ships none of them in its output, so the binary dies at load with
# "libwolfssl.so.44: cannot open shared object file" (and libFusion.so, ...).
# It's also marked `unfree` to keep Hydra from building it, so it's never a
# cached/tested binary. Rather than fight that, run the self-contained upstream
# AppImage. It bundles Qt/wolfSSL/Fusion/etc.; the FHS only supplies the libs
# AppImages assume the host provides plus the GPU userspace (the kernel-matched
# driver is bind-mounted from /run/opengl-driver).
{ pkgs }:
let
  version = "0.0.41-19492";
  src = pkgs.fetchurl {
    url = "https://github.com/RPCS3/rpcs3-binaries-linux/releases/download/build-6a15f9dc8ea46fafccdebebe9b57e21bbd5e7426/rpcs3-v0.0.41-19492-6a15f9dc_linux64.AppImage";
    hash = "sha256-IWw48BdYtR8s1CyYsRRQHnO5s/22643m98h70lSVYIQ=";
  };

  # nixpkgs' appimageTools can't unsquashfs this AppImage's filesystem, but its
  # own static runtime self-extracts fine. Newer runtimes make squashfs-root a
  # symlink to ./AppDir, so resolve it before copying.
  appdir = pkgs.runCommand "rpcs3-appdir-${version}" { } ''
    cp ${src} app.AppImage
    chmod +x app.AppImage
    ./app.AppImage --appimage-extract >/dev/null
    cp -r "$(readlink -f squashfs-root)" $out
  '';
in
pkgs.buildFHSEnv {
  name = "rpcs3";

  # The AppImage's own libraries load via the binary's $ORIGIN/../lib RPATH; the
  # set below is the libraries it expects from the host (the linuxdeploy
  # "excludelist", computed from the binaries' DT_NEEDED) plus the GPU/Qt-xcb
  # runtime bits. xcbutilcursor is dlopened by Qt's xcb platform plugin and so
  # isn't visible to a DT_NEEDED scan.
  targetPkgs =
    p:
    (with p; [
      libglvnd # libEGL/libGL/libGLX/libOpenGL
      vulkan-loader # libvulkan.so.1
      libdrm # libdrm.so.2
      libxkbcommon # libxkbcommon + libxkbcommon-x11
      wayland # libwayland-client.so.0
      e2fsprogs # libcom_err.so.2
      gmp # libgmp.so.10
      libgpg-error # libgpg-error.so.0
      fontconfig # libfontconfig.so.1
      freetype # libfreetype.so.6
      alsa-lib # libasound.so.2
      libpulseaudio
      zlib # libz.so.1
      glib
      dbus
      udev
      libusb1
    ])
    ++ (with p.xorg; [
      libX11 # libX11.so.6 + libX11-xcb.so.1
      libxcb # libxcb.so.1
      xcbutilcursor # libxcb-cursor.so.0
      libICE # libICE.so.6
      libSM # libSM.so.6
      libXext
      libXrender
      libXi
      libXrandr
      libXfixes
      libXcursor
      libXcomposite
      libXdamage
      libXtst
      libxshmfence
    ]);

  runScript = pkgs.writeShellScript "rpcs3-run" ''
    # NixOS exposes the Vulkan ICD under /run/opengl-driver.
    export VK_ICD_FILENAMES=$(echo /run/opengl-driver/share/vulkan/icd.d/*.json | tr ' ' ':')
    exec ${appdir}/AppRun "$@"
  '';
}
