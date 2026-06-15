{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
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

  # Smooth KMS / Wayland presentation on kernel 6.11+.
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
}
