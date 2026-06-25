{ config, pkgs, ... }:
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  # NVIDIA display i2c adapters return -19 (ENODEV) if probed too soon after
  # boot. Poll every 2s, retrying the new_device bind until a backlight appears
  # or 30s elapse.
  ddcciBind = pkgs.writeShellScript "ddcci-bind" ''
    for i in $(seq 1 15); do
      ls /sys/class/backlight/ddcci* 2>/dev/null | grep -q . && exit 0
      for adapter in /sys/bus/i2c/devices/i2c-*; do
        bus=$(basename "$adapter")
        num=''${bus#i2c-}
        [ -d "$adapter/$num-0037" ] && continue
        name=$(cat "$adapter/name" 2>/dev/null || true)
        case "$name" in *NVIDIA*) ;; *) continue ;; esac
        echo "ddcci 0x37" > "$adapter/new_device" 2>/dev/null || true
      done
      sleep 2
    done
  '';
in
{
  hardware.i2c.enable = true;

  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100
  '';

  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [ "ddcci_backlight" ];

  services.udev.extraRules = ''
    # Make the ddcci brightness node writable so the daemon can write without root.
    SUBSYSTEM=="backlight", KERNEL=="ddcci*", RUN+="${pkgs.coreutils}/bin/chmod a+w /sys/class/backlight/%k/brightness"
  '';

  environment.systemPackages = [ pkgs.ddcutil ];

  # Retries binding ddcci to NVIDIA display i2c adapters until one succeeds.
  systemd.services.ddcci-bind = {
    description = "Bind ddcci to NVIDIA display i2c adapters";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ddcciBind;
    };
  };

  # Watches all gamepads for Guide + DPad Up/Down and adjusts DDC brightness.
  systemd.services.ddc-brightness = {
    description = "DDC brightness control via gamepad Guide+DPad";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonEnv}/bin/python3 ${./ddc-brightness-daemon.py}";
      User = "samb";
      Restart = "always";
      RestartSec = "3s";
    };
  };
}
