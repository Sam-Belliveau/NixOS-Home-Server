{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # VA-API hardware video decode via NVDEC. Helps Firefox/mpv; does NOT work
    # with Chromium/CEF, so it won't speed up Steam's web UI.
    extraPackages = [ pkgs.nvidia-vaapi-driver ];
  };

  hardware.nvidia = {
    # Proprietary kernel modules: the open (GSP) ones fail the GLSL->SPIR-V
    # path on this GPU, which crashed the gamescope session.
    open = false;
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Select the NVIDIA VA-API driver (direct/NVDEC backend, no EGL needed).
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # Smooth KMS / Wayland presentation on kernel 6.11+.
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
}
