# VacuumTube (YouTube Leanback for the desktop) from the upstream AppImage.
#
# This is the YouTube kiosk. It's Electron (Chromium), so unlike the Firefox
# kiosks it gets NO hardware video decode here -- nvidia-vaapi-driver is
# Firefox-only. That's accepted on purpose: this box drives a 1440p panel, where
# the i9-9900K software-decodes VP9 comfortably, and VacuumTube brings what
# Leanback-in-Firefox can't: built-in controller navigation, the polished TV UI,
# and adblock/SponsorBlock. (Instagram stays on the Firefox kiosk.)
{ pkgs, ... }:
let
  version = "1.7.3";
  src = pkgs.fetchurl {
    url = "https://github.com/shy1132/VacuumTube/releases/download/v${version}/VacuumTube-x86_64.AppImage";
    hash = "sha256-StFGxFjbhp8dj2C6T3z/ngDLaAIS1UJBY4U6tXl0mkk=";
  };

  # Ordinary electron-builder AppImage, so appimageTools extracts it and wraps it
  # in its FHS (which already carries the Chromium/Electron runtime libs). rpcs3
  # needed a hand-rolled buildFHSEnv only because its AppImage wouldn't
  # unsquashfs; this one is standard.
  vacuumtube = pkgs.appimageTools.wrapType2 {
    pname = "vacuumtube";
    inherit version src;
  };

  # Kiosk launcher. Same gamescope constraints the browser kiosks hit: force
  # XWayland (Game Mode reliably shows X11 clients; native-Wayland Chromium
  # doesn't) via the Electron ozone hint, and the EGL GL backend (the default
  # trips "dri_gbm.so: Permission denied" under gamescope here). --fullscreen is
  # VacuumTube's own flag; --use-gl is forwarded to Chromium.
  vacuumtubeKiosk = pkgs.writeShellScriptBin "vacuumtube-kiosk" ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    export ELECTRON_OZONE_PLATFORM_HINT=x11
    exec ${vacuumtube}/bin/vacuumtube --fullscreen --use-gl=egl "$@"
  '';
in
{
  environment.systemPackages = [
    vacuumtube
    vacuumtubeKiosk
  ];
}
