{ config, pkgs, ... }:
{
  # Enable i2c-dev kernel module, i2c group, and udev rules for /dev/i2c-* access.
  hardware.i2c.enable = true;

  # NVIDIA proprietary driver: software I2C mode makes DDC reads more reliable.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100
  '';

  # ddcci-driver: registers each DDC-capable display as /sys/class/backlight/ddcci*
  # so Gamescope's brightness slider in the Steam Quick Access Menu drives it.
  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [ "ddcci_backlight" ];

  # NVIDIA i2c adapters can be unready when ddcci probes at module load.
  # This rule defers the DDC slave binding until udev fires for each adapter.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="i2c", IMPORT{parent}="DRIVER"
    ACTION=="add", SUBSYSTEM=="i2c", ENV{DRIVER}=="nvidia", ATTR{new_device}="ddcci 0x37"
  '';

  # ddcutil: direct DDC CLI fallback if /sys/class/backlight/ddcci* doesn't appear.
  # Usage: ddcutil setvcp 0x10 75   (brightness 0-100)
  environment.systemPackages = [ pkgs.ddcutil ];
}
